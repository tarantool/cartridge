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

    cy.get('.meta-test__statefulStorageURI input').should('be.disabled');
    cy.get('.meta-test__storagePassword input').should('be.disabled');


    cy.get('.meta-test__SubmitButton').click();
    cy.get('#root').contains('Failover change is OK...').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Eventual', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__eventualRadioBtn').click();

    cy.get('.meta-test__statefulStorageURI input').should('be.disabled');
    cy.get('.meta-test__storagePassword input').should('be.disabled');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('#root').contains('Failover change is OK...').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful: error', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click();
    cy.get('.meta-test__statefulStorageURI input').type('{selectall}{backspace}');
    cy.get('.meta-test__storagePassword input').type('{selectall}{backspace}');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('#root').contains('topology_new.failover.tarantool_params.uri invalid URI ""').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
  })

  it('Failover Stateful: success', () => {
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click();

    cy.get('.meta-test__statefulStorageURI input').should('be.enabled');
    cy.get('.meta-test__storagePassword input').should('be.enabled');

    cy.get('.meta-test__statefulStorageURI input').type('{selectall}{backspace}localhost:13303');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('#root').contains('Failover change is OK...').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');

    cy.reload();
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 4');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('button[classname="meta-test__closeClusterIssuesModal"]').click();
    cy.get('button[classname="meta-test__closeClusterIssuesModal"]').should('not.exist');
    // cy.get('.meta-test__ClusterIssuesModal').contains('warning');
    // cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    // cy.get('.meta-test__ClusterIssuesModal').should('not.be.visible');
  })

});
