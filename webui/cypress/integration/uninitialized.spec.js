describe('Schema section', () => {
  it('Schema without bootstrap', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/schema");
    cy.get('.monaco-editor textarea').should('have.value', '');

    cy.get('button[type="button"]:contains("Validate")').click();
    cy.get('#root').contains('Cluster isn\'t bootstrapped yet');
  })
});
