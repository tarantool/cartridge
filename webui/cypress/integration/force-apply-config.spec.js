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
        helpers.run_remotely(_G.cluster.main_server, function()
          local confapplier = require('cartridge.confapplier')
          confapplier.set_state('ConfiguringRoles')
          confapplier.set_state('OperationError',
            require('errors').new('ArtificialError', 'the cake is a lie')
          )
        end)
        return true
      `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: force-apply-config', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion panel');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('be.visible');
    cy.get('.meta-test__ClusterSuggestionsPanel h5').contains('Force apply configuration');
    cy.get('.meta-test__ClusterSuggestionsPanel span').contains(
      'Some instances are misconfigured. ' +
      'You can heal it by reapplying configuration forcefully.');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-1)').should('contain', 'OperationError');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should('not.contain', 'OperationError');

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
