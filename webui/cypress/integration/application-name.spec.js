describe('Application name', () => {

  it('Application name', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/dashboard");
    cy.contains('app_name.instance_name');
  })
});
