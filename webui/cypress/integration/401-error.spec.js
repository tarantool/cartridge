describe('Test 401 error', () => {
  it('Test 401 error', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/dashboard");
    cy.get('.meta-test__LoginFormSplash').contains('Authorization');
    cy.get('.meta-test__LoginFormSplash').contains('Please, input your credentials');

    cy.get('input[name="username"]').type('admin');
    cy.get('input[name="password"]').type('test-cluster-cookie{enter}');

    cy.get('.meta-test__LogoutBtn').contains('Cartridge Administrator');
    cy.get('.meta-test__LogoutBtn').click().contains('Log out').click();

    cy.get('.meta-test__LoginFormSplash').should('be.visible');
  });
});
