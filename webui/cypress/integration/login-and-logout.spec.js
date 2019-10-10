//Steps:
//1. Login error
//2. Success login


describe('Login', () => {
  it('Login error', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('error')
      .should('have.value', 'error');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('secret-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('Authentication failed');//try to found logout btn
  })
  it('Success login', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('{selectall}{del}')
      .type('admin')
      .should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('secret-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LogoutBtn');//try to found logout btn
  })
  it('Logout', () => {
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('li').contains('Log out').click();
  })
});