//Steps:
//1.Failover
//      Failover turn on
//      Failover turn off

describe('Failover', () => {
  it('Failover turn on', () => {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica set');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').get(':checkbox').should('not.be.checked');
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__FailoverModal').contains('Failover disabled').should('exist');
    cy.get('.meta-test__SubmitButton').contains('Enable').click();
    cy.get('#root').contains('Failover change is OK...').click();
    cy.get('.meta-test__FailoverButton').get(':checkbox').should('be.checked');
  })

  it('Failover turn off', () => {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica set');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').get(':checkbox').should('be.checked');
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__FailoverModal').contains('Failover enabled').should('exist');
    cy.get('.meta-test__SubmitButton').contains('Disable').click();
    cy.get('#root').contains('Failover change is OK...').click();
    cy.get('.meta-test__FailoverButton').get(':checkbox').should('not.be.checked');
  })
});
