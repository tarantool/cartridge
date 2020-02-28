describe('Schema section', () => {
  it('Configuration blacklisted', () => {
    // Blacklisted pages can be visited
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/configuration');
    cy.get('#root').contains('Download configuration').should('exist');
    cy.get('#root').contains('Upload configuration').should('exist');
    cy.get('.ScrollbarsCustom-Content').get('a[href="/admin/cluster/dashboard"]').should('exist');
    // But it shouldn't be listed in menu
    cy.get('.ScrollbarsCustom-Content').get('a[href="/admin/cluster/configuration"]').should('not.exist');
  });
});
