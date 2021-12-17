describe('Checking for situations when a connection is lost using SIGSTOP', () => {
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

  function openServerDetailsModal(serverAlias) {
    cy.get('.ServerLabelsHighlightingArea')
      .contains(serverAlias)
      .closest('.ServerLabelsHighlightingArea')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
      .click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Server details').click();
  }

  function tryToSubmitTestZone() {
    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="zone_name"]').type('Test');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
  }

  it('Test: sigstop', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Stop server');
    ////////////////////////////////////////////////////////////////////
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: false });
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');

    //Check Issue
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('critical');
    cy.get('.meta-test__ClusterIssuesModal').contains(
      'Replication from localhost:13302 (dummy-2) to localhost:13301 (dummy-1)'
    );
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();

    //Check mem stats
    cy.contains('dummy-1')
      .closest('[data-component=ReplicasetServerListItem]')
      .find('[data-component=ReplicasetListMemStat]')
      .should('be.visible');
    cy.contains('dummy-2')
      .closest('[data-component=ReplicasetServerListItem]')
      .find('[data-component=ReplicasetListMemStat]')
      .should('not.exist');

    //Check server status
    cy.contains('dummy-1').closest('[data-component=ReplicasetServerListItem]').contains('healthy');
    cy.contains('dummy-2').closest('[data-component=ReplicasetServerListItem]').contains('unreachable');
    cy.contains('dummy-2')
      .closest('[data-component=ReplicasetServerListItem]')
      .find('[data-component=ReplicasetListStatus]')
      .invoke('attr', 'data-value-message')
      .should('eq', 'Server status is "dead"');

    //Try to add new zone in server details
    openServerDetailsModal('dummy-2');
    tryToSubmitTestZone();
    cy.get('.ZoneAddModal_error').find('span:contains(Timeout exceeded)');
    cy.get('h2:contains(Add name of zone)').next().click();
    cy.get('.meta-test__ServerDetailsModal button:contains(Close)').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Cont server');
    ////////////////////////////////////////////////////////////////////
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: false });
    cy.reload();

    //Cluster page: Try to add new zone
    openServerDetailsModal('dummy-2');
    tryToSubmitTestZone();
    cy.get('.meta-test__ServerDetailsModal button:contains(Close)').click();

    //Cluster page: Check mem stats
    cy.contains('dummy-1')
      .closest('[data-component=ReplicasetServerListItem]')
      .find('[data-component=ReplicasetListMemStat]')
      .should('be.visible');
    cy.contains('dummy-2')
      .closest('[data-component=ReplicasetServerListItem]')
      .find('[data-component=ReplicasetListMemStat]')
      .should('be.visible');

    //Check server status
    cy.contains('dummy-1').closest('[data-component=ReplicasetServerListItem]').contains('healthy');
    cy.contains('dummy-2').closest('[data-component=ReplicasetServerListItem]').contains('healthy');

    //Cluster page: Check Issue
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 0');
  });
});
