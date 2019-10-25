//Steps:
//1. Login
//2. Enable Auth
//3. Disable auth


describe('Auth', () => {

  it('Login and Enable Auth', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('admin')
      .should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('a[href="/admin/cluster/users"]').click({ force: true });
    cy.get('.meta-test__AuthToggle').click();
    cy.get('.meta-test__ConfirmModal').contains('Enable').click({ force: true }); //component: AuthToggleButton
  })
  it('Login and Disable auth', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('input[name="username"]')
      .type('admin')
      .should('have.value', 'admin');
    cy.get('input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('a[href="/admin/cluster/users"]').click({ force: true });
    cy.get('.meta-test__AuthToggle').click();
    cy.get('.meta-test__ConfirmModal').contains('Disable').click({ force: true }); //component: AuthToggleButton
  })
});