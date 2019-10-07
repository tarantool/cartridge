//Steps:
//1. Login error
//2. Success login


describe('Login', () => {
  it('Login error', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__AuthToggleBtn').click();
  })
});