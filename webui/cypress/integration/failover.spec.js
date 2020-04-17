const testPort = `:13302`;

describe('Failover', () => {

  before(function() {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica sets');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
  })

  it('Failover Disable', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__disableRadioBtn').click();

    cy.get('.meta-test__stateboardURI input').should('be.disabled');
    cy.get('.meta-test__stateboardPassword input').should('be.disabled');


    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + * + span:contains(disabled)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Eventual', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__eventualRadioBtn').click();

    cy.get('.meta-test__stateboardURI input').should('be.disabled');
    cy.get('.meta-test__stateboardPassword input').should('be.disabled');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + * + span:contains(eventual)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful: error', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click();
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__FailoverModal')
      .contains('topology_new.failover.tarantool_params.uri: Invalid URI ""')
      .trigger('keydown', { keyCode: 27, which: 27 });
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful: success', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click().click();

    cy.get('.meta-test__stateboardURI input').should('be.enabled');
    cy.get('.meta-test__stateboardPassword input').should('be.enabled');

    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost' + testPort);

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + * + span:contains(stateful)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');
  })

  it('Check issues', () => {
    cy.reload();
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 4');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('warning');
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.reload();
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal')
      .contains('Replication from localhost' + testPort);
    cy.get('.meta-test__closeClusterIssuesModal').click();

    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.reload();
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal')
      .contains('Replication from localhost' + testPort).should('not.exist');
    cy.get('.meta-test__closeClusterIssuesModal').click();
  })

});
