describe('Change advertise uri', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = 'test-cluster-cookie',
        replicasets = {{
          alias = 'test-replicaset',
          roles = {'vshard-router', 'vshard-storage', 'failover-coordinator'},
          servers = {{http_port = 8080}},
        }}
      })
      _G.cluster:start()
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      _G.cluster.main_server:stop()

      _G.cluster.main_server.net_box_port = nil
      _G.cluster.main_server.advertise_uri = nil
      _G.cluster.main_server.advertise_port = 13312
      _G.cluster.main_server:start()
      return true
    `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: change-advertise-uri', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__ProbeServerBtn').should('exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Server In replica set');
    ////////////////////////////////////////////////////////////////////
    cy.get('li').contains('test-replicaset').closest('li').should('contain', 'healthy');
    cy.get('.meta-test__ReplicasetServerList').should('contain', 'localhost:13312');
    cy.get('.meta-test__haveIssues');

    ////////////////////////////////////////////////////////////////////
    cy.log('Issues');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('warning');
    cy.get('.meta-test__ClusterIssuesModal').contains(
      'Advertise URI (localhost:13312) differs from clusterwide config (localhost:13301)'
    );
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Cluster Suggestions Panel');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').contains('Change advertise URI');
    cy.get('.meta-test__ClusterSuggestionsPanel').contains(
      'Seems that some instances were restarted with' + ' a different advertise_uri. Update configuration to fix it.'
    );
    cy.get('.meta-test__ClusterSuggestionsPanel').find('button:contains(Review changes)').click();

    cy.get('.meta-test__AdvertiseURISuggestionModal').contains('Change advertise URI');
    cy.get('.meta-test__AdvertiseURISuggestionModal').contains(
      'One or more servers were restarted with a new advertise uri'
    );
    cy.get('.meta-test__AdvertiseURISuggestionModal').contains('localhost:13301 -> localhost:13312');
    cy.get('.meta-test__AdvertiseURISuggestionModal').find('button:contains(Update)').click();
    cy.get('.meta-test__AdvertiseURISuggestionModal').should('not.exist');
  });
});
