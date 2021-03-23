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
    cy.log('Inspect suggestion modal');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();
    cy.get('.meta-test__ForceApplySuggestionModal h2').contains('Force apply configuration');
    cy.get('.meta-test__ForceApplySuggestionModal p').contains(
      'Some instances are misconfigured. ' +
      'You can heal it by reapplying configuration forcefully.');
    cy.get('.meta-test__ForceApplySuggestionModal span').contains('Operation error');
    cy.get('.meta-test__ForceApplySuggestionModal span button').contains('Deselect all');
    cy.get('.meta-test__ForceApplySuggestionModal input[type="checkbox"]').should('be.checked');
    cy.get('.meta-test__ForceApplySuggestionModal span').contains('localhost:13301 (dummy-1)');
    cy.get('.meta-test__ForceApplySuggestionModal button').contains('Force apply').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('OperationError is gone');
    ////////////////////////////////////////////////////////////////////
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-1)').should('not.contain', 'OperationError');
  });
});
