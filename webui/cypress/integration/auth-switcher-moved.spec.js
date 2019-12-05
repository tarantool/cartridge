describe('Auth switcher moved', () => {

  it('Login and Enable Auth', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__LoginBtn').click({ force: true });
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('admin');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__AuthToggle').click();
    cy.get('.meta-test__ConfirmModal').contains('Enable').click({ force: true });
  })

    it('Login and Disable Auth', () => {
      cy.visit(Cypress.config('baseUrl'));
      cy.get('input[name="username"]')
        .type('admin');
      cy.get('input[name="password"]')
        .type('test-cluster-cookie');
      cy.get('.meta-test__LoginFormBtn').click({ force: true });
      cy.get('.meta-test__AuthToggle').click();
      cy.get('.meta-test__ConfirmModal').contains('Disable').click({ force: true });
     //try to open Users Page: fail
      cy.get('a[href="/admin/cluster/users"]').should('not.exist');
    })
});