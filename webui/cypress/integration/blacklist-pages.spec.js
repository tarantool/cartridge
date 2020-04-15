describe('Schema section', () => {
  it('Configuration blacklisted', () => {
    cy.visit(Cypress.config('baseUrl'));
    // Blacklisted pages aren't listed in menu
    cy.contains('Not loaded').should('not.exist');
    cy.get('.meta-test__UnconfiguredServerList').contains('spare');
    cy.get('a[href="/admin/cluster/dashboard"]').should('exist');
    cy.get('a[href="/admin/cluster/configuration"]').should('not.exist');
    // Blacklisted pages can't be visited
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/configuration');
    cy.contains('Not loaded').should('exist');
  });
});
