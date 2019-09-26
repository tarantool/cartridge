//Steps:
//1.Join Replica Set
//      Press the button Configure
//      Go to tab Join Replica Set
//      Check replica set
//      Press the button Join replica set

describe('Join Replica Set', () => {
  it('Join Replica Set', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.UnconfiguredServerList button[type="button"]').contains('Configure').click();
    cy.get('.ConfigureServerModal').contains('Join Replica Set').click();
    cy.get('.ConfigureServerModal input[type="radio"]').eq(0).check({ force: true });
    cy.get('.ConfigureServerModal button[type="submit"]').contains('Join replica set').click();
    cy.get('#root').contains('Join is OK. Please wait for list refresh...');
  })
});