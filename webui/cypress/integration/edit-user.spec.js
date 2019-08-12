//Steps:
//1. Edit user
//      Open edit user dialog
//      Edit user

describe('Edit user', () => {
  it('Edit user', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__UsersTable').find('button').eq(1).click();
    cy.get('li').contains('Edit user').click();
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
});