//Steps:
//1. Enable Auth
//2. Disable auth


describe('Login', () => {
  it('Login error', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__AuthToggleBtn').click();
  })
});