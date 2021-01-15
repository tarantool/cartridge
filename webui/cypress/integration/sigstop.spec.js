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
      `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function openServerDetailsModal(serverAlias) {
    cy.get('li').contains(serverAlias).closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *')
      .contains('Server details').click();
  };

  function tryToSubmitTestZone() {
    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="uri"]').type('Test');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
  };

  it('Stop server', () => {
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: false });
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');

    //Check Issue
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal')
      .contains("warning: Replication from localhost:13302 (dummy-2) to localhost:13301 (dummy-1) is disconnected (timed out)");
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();

    //Check buckets
    cy.contains('dummy-1').closest('li').find('.meta-test__bucketIcon').should('be.visible');
    cy.contains('dummy-2').closest('li').find('.meta-test__bucketIcon').should('not.be.visible');

    //Check server status
    cy.contains('dummy-1').closest('li').contains('healthy');
    cy.contains('dummy-2').closest('li').contains('Server status is "dead"');

    //Try to add new zone in server details
    openServerDetailsModal('dummy-2');
    tryToSubmitTestZone();
    cy.get('.ZoneAddModal_error').find('span:contains(Timeout exceeded)');
    cy.get('h2:contains(Add name of zone)').next().click();
    cy.get('.meta-test__ServerDetailsModal button:contains(Close)').click();
  });

  it('Cont server', () => {

    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: false });
    cy.reload();

    //Cluster page: Try to add new zone
    openServerDetailsModal('dummy-2');
    tryToSubmitTestZone();
    cy.get('.ZoneAddModal_error').find('span:contains(Two-phase commit is locked)', { timeout: 15000 });
    cy.get('h2:contains(Add name of zone)').next().click();
    cy.get('.meta-test__ServerDetailsModal button:contains(Close)').click();

    //Cluster page: Check buckets
    cy.contains('dummy-1').closest('li').find('.meta-test__bucketIcon').should('be.visible');
    cy.contains('dummy-2').closest('li').find('.meta-test__bucketIcon').should('be.visible');

    //Check server status
    cy.contains('dummy-1').closest('li').contains('healthy');
    cy.contains('dummy-2').closest('li').contains('healthy');

    //Cluster page: Check Issue
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal')
      .contains("warning: Configuration is prepared and locked on localhost:13302 (dummy-2)");
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
  });

});