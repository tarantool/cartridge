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
  })

  it('Success login', () => {
    cy.visit(Cypress.config('baseUrl'));
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
    cy.get('li').contains('Log out').click();
  })

  it('Check login user with empty name', () => {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/users');

    //create user with fullname:
    cy.get('.meta-test__addUserBtn').click();
    cy.get('.meta-test__UserAddForm input[name="username"]').type('testuser');
    cy.get('.meta-test__UserAddForm input[name="password"]').type('testpassword');
    cy.get('.meta-test__UserAddForm input[name="fullname"]').type('testfullname');
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
    cy.get('.meta-test__LogoutBtn span:contains(testfullname)');

    //delete fullname and reload a page:
    cy.get('.meta-test__UsersTable').find('button').eq(1).click();
    cy.get('li').contains('Edit user').click();
    cy.get('.meta-test__UserEditModal input[name="fullname"]')
      .type('{selectall}{del}');
    cy.get('.meta-test__UserEditModal button[type="submit"]').contains('Save').click();

    cy.reload();
    cy.get('.meta-test__LogoutBtn span:contains()');
    cy.get('.meta-test__LoginBtn').should('not.exist');

    cy.get('.meta-test__UsersTable').find('button').eq(1).click();
    cy.get('li').contains('Remove user').click();
    cy.get('.meta-test__UserRemoveModal button[type="button"]').contains('Remove').click();
  })
});
