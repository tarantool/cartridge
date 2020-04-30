describe('Schema section', () => {
  it('Schema without bootstrap', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/schema");
    cy.get('.monaco-editor textarea').should('have.value', '');
  })
});
