describe('Users', () => {

  before(function() {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('a[href="/admin/cluster/users"]').click();
  })

  it('Tab title on Users page', () => {
    cy.title().should('eq', 'cartridge-testing.r1: Users')
  })

  it('Add user', () => {
    cy.get('.meta-test__addUserBtn').click({ force: true });
    cy.get('.meta-test__UserAddForm input[name="username"]')
      .type('user_do_not_touch')
      .should('have.value', 'user_do_not_touch');
    cy.get('.meta-test__UserAddForm input[name="password"]')
      .type('123');
    cy.get('.meta-test__UserAddForm button[type="submit"]').contains('Add').click();
    cy.get('.meta-test__UsersTable').contains('user_do_not_touch');
  })

  it('Edit user', () => {
    cy.get('.meta-test__UsersTable').find('button').eq(1).click();
    cy.get('.meta-test__UsersTableItem__dropdown *').contains('Edit user').click();
    cy.get('.meta-test__UserEditModal input[name="password"]')
      .type('{selectall}{del}')
      .type('321');
    cy.get('.meta-test__UserEditModal input[name="email"]')
      .type('donottouch@qq.qq')
      .should('have.value', 'donottouch@qq.qq');
    cy.get('.meta-test__UserEditModal input[name="fullname"]')
      .type('Full Name donottouch')
      .should('have.value', 'Full Name donottouch');
    cy.get('.meta-test__UserEditModal button[type="submit"]').contains('Save').click();
    cy.get('.meta-test__UsersTable').contains('Full Name donottouch');
  })

  it('Remove user', () => {
    cy.get('.meta-test__UsersTable li:contains(user_do_not_touch)').find('button').click();
    cy.get('.meta-test__UsersTableItem__dropdown *').contains('Remove user').click();
    cy.get('.meta-test__UserRemoveModal button[type="button"]:contains(Remove)').click();

    cy.get('.meta-test__UsersTable').contains('user_do_not_touch').should('not.exist');
  })

});
