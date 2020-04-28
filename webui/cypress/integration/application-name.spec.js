describe('Application name', () => {

  it('Application name', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/dashboard");
    cy.contains('cartridge-testing.r1');
  })
});
