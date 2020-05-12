//Steps:
//1.Join Replica Set
//      Press the button Configure
//      Go to tab Join Replica Set
//      Check replica set
//      Press the button Join replica set

describe('Join Replica Set', () => {
  it('Join Replica Set', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('li').contains('localhost:13302').closest('li').find('button').contains('Configure').click({ force: true });
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();
    cy.get('.meta-test__ConfigureServerModal input[name="replicasetUuid"]').eq(0).check({ force: true });
    cy.get('.meta-test__JoinReplicaSetBtn').click();
    cy.get('#root').contains('Join is OK. Please wait for list refresh...');//add to frontend-core classname for notification
  })
});
