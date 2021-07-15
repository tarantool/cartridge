describe('Disable server', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()

        _G.cluster = helpers.Cluster:new({
          datadir = fio.tempdir(),
          server_command = helpers.entrypoint('srv_basic'),
          use_vshard = false,
          cookie = helpers.random_cookie(),
          replicasets = {{
            uuid = helpers.uuid('a'),
            alias = 'dummy',
            roles = {},
            servers = {{http_port = 8080}, {}},
          }},
        })

        _G.cluster:start()
        return true
      `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function causeOperationError(alias) {
    cy.task('tarantool', {
      code: `
        local srv = _G.cluster:server('${alias}')
        return helpers.run_remotely(srv, function()
          local confapplier = require('cartridge.confapplier')
          local errors = require('errors')
          local err = errors.new('ArtificialError', 'the cake is a lie')
          confapplier.set_state('ConfiguringRoles')
          confapplier.set_state('OperationError', err)
        end)
      `
    });
  }

  function causeConfigLock(alias) {
    cy.task('tarantool', {
      code: `
        local srv = _G.cluster:server('${alias}')
        return helpers.run_remotely(srv, function()
          local confapplier = require('cartridge.confapplier')
          local cfg = confapplier.get_active_config():get_plaintext()
          _G.__cartridge_clusterwide_config_prepare_2pc(cfg)
        end)
      `
    });
  }

  function causeConfigMismatch(alias) {
    cy.task('tarantool', {
      code: `
        local srv = _G.cluster:server('${alias}')
        return helpers.run_remotely(srv, function()
          local confapplier = require('cartridge.confapplier')
          local cfg = confapplier.get_active_config():copy()
          cfg:set_plaintext('todo1.txt', '- Test config mismatch')
          cfg:lock()
          confapplier.apply_config(cfg)
        end)
      `
    });
  }

  it('Test: force-apply-config', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');

    causeOperationError('dummy-1');
    causeConfigMismatch('dummy-2');
    causeConfigLock('dummy-2');
    causeOperationError('dummy-2');

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion panel');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('be.visible');
    cy.get('.meta-test__ClusterSuggestionsPanel h5').contains('Force apply configuration');
    cy.get('.meta-test__ClusterSuggestionsPanel span').contains(
      'Some instances are misconfigured. ' +
      'You can heal it by reapplying configuration forcefully.');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-1)').should('contain', 'OperationError');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should('contain', 'OperationError');

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect issues');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 2');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('warning');
    cy.get('.meta-test__ClusterIssuesModal')
      .contains('Configuration checksum mismatch on localhost:13302 (dummy-2)');
    cy.get('.meta-test__ClusterIssuesModal').contains('warning');
    cy.get('.meta-test__ClusterIssuesModal')
      .contains('Configuration is prepared and locked on localhost:13302 (dummy-2)');
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion modal');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();
    cy.get('.meta-test__ForceApplySuggestionModal h2').contains('Force apply configuration');
    cy.get('.meta-test__ForceApplySuggestionModal p').contains(
      'Some instances are misconfigured. ' +
      'You can heal it by reapplying configuration forcefully.');

    cy.get('.meta-test__ForceApplySuggestionModal').find('.meta-test__errorField').eq(0).as('operErrorField');
    cy.get('@operErrorField').find('span').contains('Operation error');
    cy.get('@operErrorField').find('span button').contains('Deselect all');
    cy.get('@operErrorField').contains('localhost:13301 (dummy-1)')
      .find('input[type="checkbox"]').should('be.checked');
    cy.get('@operErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').should('be.checked');

    cy.get('.meta-test__ForceApplySuggestionModal').find('.meta-test__errorField').eq(1).as('confErrorField');
    cy.get('@confErrorField').find('span').contains('Configuration error');
    cy.get('@confErrorField').find('span button').contains('Deselect all');
    cy.get('@confErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').should('be.checked');

    ////////////////////////////////////////////////////////////////////
    cy.log('Uncheck localhost:13302 (dummy-2)');
    ////////////////////////////////////////////////////////////////////
    cy.get('@operErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').click({ force: true });
    cy.get('@operErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').should('not.be.checked');
    cy.get('@confErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').should('not.be.checked');

    ////////////////////////////////////////////////////////////////////
    cy.log('Close suggestion modal and save checkbox value');
    ////////////////////////////////////////////////////////////////////
    cy.get('h2:contains(Force apply configuration)').next().click();
    cy.get('.meta-test__ForceApplySuggestionModal').should('not.exist');
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();
    cy.get('@operErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').should('not.be.checked');
    cy.get('@confErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').should('not.be.checked');

    ////////////////////////////////////////////////////////////////////
    cy.log('Force apply 1 server: dummy-2');
    ////////////////////////////////////////////////////////////////////
    cy.get('@operErrorField').contains('localhost:13302 (dummy-2)')
      .find('input[type="checkbox"]').click({ force: true });
    cy.get('@operErrorField').contains('localhost:13301 (dummy-1)')
      .find('input[type="checkbox"]').click({ force: true });
    cy.get('.meta-test__ForceApplySuggestionModal button').contains('Force apply').click();
    cy.get('.meta-test__ClusterSuggestionsPanel').should('be.visible');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-1)').should('contain', 'OperationError');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should('not.contain', 'OperationError');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 0');

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion modal after force apply 1 server: dummy-2');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();
    cy.get('.meta-test__ForceApplySuggestionModal h2').contains('Force apply configuration');
    cy.get('.meta-test__ForceApplySuggestionModal p').contains(
      'Some instances are misconfigured. ' +
      'You can heal it by reapplying configuration forcefully.');

    cy.get('.meta-test__ForceApplySuggestionModal').find('.meta-test__errorField').as('operErrorField');
    cy.get('@operErrorField').find('span').contains('Operation error');
    cy.get('@operErrorField').contains('localhost:13301 (dummy-1)')
      .find('input[type="checkbox"]').click({ force: true });
    cy.get('@operErrorField').find('span button').contains('Deselect all');
    cy.get('@operErrorField').contains('localhost:13301 (dummy-1)')
      .find('input[type="checkbox"]').should('be.checked');
    cy.get('@operErrorField').contains('localhost:13302 (dummy-2)').should('not.exist');
  });
});
