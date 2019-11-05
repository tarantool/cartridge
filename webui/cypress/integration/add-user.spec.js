//Steps:
//1. Add user
//      Open add user dialog
//      Add user
//      press Escape for close dialog
//      press Enter in Add user dialog

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

  it('press Escape for close dialog', () => {
    cy.get('.meta-test__addUserBtn').click({ force: true }); //webui/src/pages/Users/index.js
    cy.get('.meta-test__UserAddForm').type('{esc}');
    cy.get('.meta-test__UserAddForm').should('not.exist');
  })

  it('press Enter in Add user dialog', () => {
    cy.get('.meta-test__addUserBtn').click({ force: true }); //webui/src/pages/Users/index.js
    cy.get('.meta-test__UserAddForm').type('{enter}');
    cy.get('.meta-test__UserAddForm').contains('username is a required field');
  })
});