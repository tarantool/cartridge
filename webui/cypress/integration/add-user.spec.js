//Steps:
//1. Add user
//      Open add user dialog
//      Add user

describe('Add user', () => {
  it('Add user', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__addUserBtn').click({ force: true }); //webui/src/pages/Users/index.js
    cy.get('.meta-test__UserAddForm input[name="username"]')
      .type('user_do_not_touch')
      .should('have.value', 'user_do_not_touch');
    cy.get('.meta-test__UserAddForm input[name="password"]')
      .type('123');
    cy.get('.meta-test__UserAddForm button[type="submit"]').contains('Add').click();
    cy.get('.meta-test__UsersTable').contains('user_do_not_touch');

  })
});