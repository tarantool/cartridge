describe('Failover', () => {

  before(() => {
    cy.task('tarantool', {code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        replicasets = {{
          alias = 'dummy',
          roles = {},
          servers = {{http_port = 8080}, {}},
        }}
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
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
  });

  function etcd2InputsShouldNotExist() {
    cy.get('.meta-test__etcd2Username input').should('not.exist');
    cy.get('.meta-test__etcd2Password input').should('not.exist');
    cy.get('.meta-test__etcd2LockDelay input').should('not.exist');
    cy.get('.meta-test__etcd2Prefix input').should('not.exist');
    cy.get('.meta-test__etcd2Endpoints textarea').should('not.exist');
  }

  it('Failover Disabled', () => {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__disableRadioBtn').click();
    cy.get('.meta-test__stateboardURI input').should('be.disabled');
    cy.get('.meta-test__stateboardPassword input').should('be.disabled');
    etcd2InputsShouldNotExist()

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(disabled)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Eventual', () => {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__eventualRadioBtn').click();
    cy.get('.meta-test__stateboardURI input').should('be.disabled');
    cy.get('.meta-test__stateboardPassword input').should('be.disabled');
    etcd2InputsShouldNotExist()

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(eventual)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful - TARANTOOL: error', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click().click();
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__FailoverModal')
      .contains('topology_new.failover.tarantool_params.uri: Invalid URI ""')
      .trigger('keydown', { keyCode: 27, which: 27 }); // press esc button
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful - TARANTOOL: success', () => {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click().click();
    cy.get('.meta-test__stateProviderChoice').find('button')
      .then($button => {
        expect($button).to.have.text('tarantool');
      })

    cy.get('.meta-test__stateboardURI input').should('be.enabled');
    cy.get('.meta-test__stateboardPassword input').should('be.enabled');
    etcd2InputsShouldNotExist()

    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:14401');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');
  })

  it('Failover Stateful - ETCD2: success', () => {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click().click();
    cy.get('.meta-test__stateProviderChoice').find('button').click();
    cy.contains('etcd2').click();
    cy.get('.meta-test__stateProviderChoice').find('button')
      .then($button => {
        expect($button).to.have.text('etcd2')
      })

    cy.get('.meta-test__stateboardURI input').should('not.exist');
    cy.get('.meta-test__stateboardPassword input').should('not.exist');

    cy.get('.meta-test__etcd2Username input').should('have.value', '');
    cy.get('.meta-test__etcd2Password input').should('have.value', '');
    cy.get('.meta-test__etcd2LockDelay input').should('have.value', '10');
    cy.get('.meta-test__etcd2Prefix input').should('have.value', '/');
    cy.get('.meta-test__etcd2Endpoints textarea')
      .should('have.text', 'http://127.0.0.1:4001\nhttp://127.0.0.1:2379');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');
  })

  it('Check issues', () => {
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 4');
    cy.get('.meta-test__ClusterIssuesButton').click();

    cy.get('.meta-test__ClusterIssuesModal')
      .contains("warning: Can't obtain failover coordinator: ");
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    cy.get('.meta-test__haveIssues').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesModal').contains(
      "warning: Consistency on localhost:13301 (dummy-1) isn't reached yet"
    );
  })
});
