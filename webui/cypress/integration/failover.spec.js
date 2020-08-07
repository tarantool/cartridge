const testPort = `:13302`;

describe('Failover', () => {

  before(function () {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica sets');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
  })

  function etcd2InputsShouldNotExist() {
    cy.get('.meta-test__etcd2Username input').should('not.exist');
    cy.get('.meta-test__etcd2Password input').should('not.exist');
    cy.get('.meta-test__etcd2LockDelay input').should('not.exist');
    cy.get('.meta-test__etcd2Prefix input').should('not.exist');
    cy.get('.meta-test__etcd2Endpoints textarea').should('not.exist');
  }

  it('Failover Disable', () => {
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

  it('Failover Stateful: error', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click().click();
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__FailoverModal')
      .contains('topology_new.failover.tarantool_params.uri: Invalid URI ""')
      .trigger('keydown', { keyCode: 27, which: 27 });
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful - TARANTOOL: success', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click().click();

    cy.get('.meta-test__stateProviderChoice').find('button')
      .then(($button) => {
        expect($button).to.have.text('tarantool')
      })

    cy.get('.meta-test__stateboardURI input').should('be.enabled');
    cy.get('.meta-test__stateboardPassword input').should('be.enabled');
    etcd2InputsShouldNotExist()

    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost' + testPort);

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');
  })

  it('Check issues', () => {
    cy.reload();
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 6');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal', { timeout: 6000 }).contains('warning');
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    cy.get('.meta-test__haveIssues').should('exist');

    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.reload();
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal', { timeout: 6000 })
      .contains(
        'Replication from localhost' + testPort + ' (storage)' +
        ' to localhost:13304 (storage-2): long idle'
      );
    cy.get('.meta-test__closeClusterIssuesModal').click();

    cy.get('.meta-test__haveIssues').parents('li:contains(storage1-do-not-use-me)');

    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.reload();
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal', { timeout: 6000 })
      .contains(
        'Replication from localhost' + testPort + ' (storage)' +
        ' to localhost:13304 (storage-2): long idle'
      )
      .should('not.exist');
    cy.get('.meta-test__closeClusterIssuesModal').click();
  })

  it('Failover Stateful - ETCD2: success', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click().click();

    cy.get('.meta-test__stateProviderChoice').find('button').click();
    cy.contains('etcd2').click();

    cy.get('.meta-test__stateProviderChoice').find('button')
      .then(($button) => {
        expect($button).to.have.text('etcd2')
      })

    cy.get('.meta-test__stateboardURI input').should('not.exist');
    cy.get('.meta-test__stateboardPassword input').should('not.exist');

    cy.get('.meta-test__etcd2Username input').should('have.value', '');
    cy.get('.meta-test__etcd2Password input').should('have.value', '');
    cy.get('.meta-test__etcd2LockDelay input').should('have.value', '10');
    cy.get('.meta-test__etcd2Prefix input').should('have.value', '/');
    cy.get('.meta-test__etcd2Endpoints').find('textarea')
      .then(($textarea) => {
        expect($textarea).to.have.text('http://127.0.0.1:4001\nhttp://127.0.0.1:2379')
      })

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');
  })

});
