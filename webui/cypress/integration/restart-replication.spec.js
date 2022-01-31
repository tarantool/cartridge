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
          env = {TARANTOOL_REPLICATION_CONNECT_QUORUM = 0},
          replicasets = {{
            uuid = helpers.uuid('a'),
            alias = 'dummy',
            roles = {},
            servers = {{http_port = 8080}, {}, {}},
          }},
        })

        _G.cluster:start()
        _G.cluster.main_server.net_box:call(
          'package.loaded.cartridge.failover_set_params',
          {{failover_timeout = 0}}
        )
        return true
      `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: restart-replicasets', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');

    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Add issue');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', {
      code: `
      _G.cluster:server('dummy-2').net_box:call('box.cfg', {{replication = box.NULL}})
    `,
    });

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion panel');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('be.visible');
    cy.testElementScreenshots('ClusterSuggestionsPanel', 'div.meta-test__ClusterSuggestionsPanel');
    cy.get('.meta-test__ClusterSuggestionsPanel h5').contains('Restart replication');
    cy.get('.meta-test__ClusterSuggestionsPanel span').contains(
      `The replication isn't all right. Restart it, maybe it helps.`
    );

    //Check health state for Servers and  ReplicaSet
    cy.get('[data-component=ReplicasetListHeader]').contains('Total replicasets1');
    cy.get('[data-cy=meta-test__replicaSetSection]').contains('have issues');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(2).contains('healthy');

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion modal');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();
    cy.testElementScreenshots('RestartReplicationSuggestionModal', 'div.meta-test__RestartReplicationSuggestionModal');
    cy.get('.meta-test__RestartReplicationSuggestionModal h2').contains('Restart replication');
    cy.get('.meta-test__RestartReplicationSuggestionModal p').contains(
      "The replication isn't all right. Restart it, maybe it helps."
    );
    cy.get('.meta-test__RestartReplicationSuggestionModal li').contains('localhost:13302 (dummy-2)');
    cy.get('.meta-test__RestartReplicationSuggestionModal button').contains('Restart').click();

    cy.get('.meta-test__RestartReplicationSuggestionModal').should('not.exist');
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
  });
});
