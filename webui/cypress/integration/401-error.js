describe('Test 401 error', () => {
  it('Test 401 error', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/dashboard");
    cy.contains('Authorization');
    cy.contains('Please, input your credentials');
    cy.contains('Not loaded').should('not.exist');
  });
});
