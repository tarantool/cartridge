describe('Login', () => {

  it('Login error', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('error')
      .should('have.value', 'error');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('Authentication failed');//try to found logout btn
    cy.get('.meta-test__LoginForm button[type="button"]').contains('Cancel').click();
  })

  it('Success login', () => {
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('{selectall}{del}')
      .type('admin')
      .should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LogoutBtn');//try to found logout btn
  })

  it('Logout', () => {
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();
  })

  it('Check login user with empty name', () => {
    cy.get('a[href="/admin/cluster/users"]').click();

    //create user without fullname:
    cy.get('.meta-test__addUserBtn').click();
    cy.get('.meta-test__UserAddForm input[name="username"]').type('testuser');
    cy.get('.meta-test__UserAddForm input[name="password"]').type('testpassword');
    cy.get('.meta-test__UserAddForm button:contains(Add)').click();

    //login user:
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('{selectall}{del}')
      .type('testuser');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('testpassword');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LoginBtn').should('not.exist');
    cy.get('.meta-test__LogoutBtn');

    //logout and remove testuser:
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();

    cy.get('.meta-test__UsersTable li:contains(testuser)').find('button').click();
    cy.get('.meta-test__UsersTableItem__dropdown *').contains('Remove user').click();
    cy.get('.meta-test__UserRemoveModal button[type="button"]:contains(Remove)').click();
  })
});
