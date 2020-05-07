//Steps:
//1. Remove user
//      Open remove user dialog
//      Remove user

describe('Remove user', () => {
  it('Remove user', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__UsersTable').find('button').eq(1).click();
    cy.get('li').contains('Remove user').click();
    cy.get('.meta-test__UserRemoveModal button[type="button"]:contains(Remove)').click();
    cy.get('.meta-test__addUserBtn'); //it is a litle delay
    cy.get('.meta-test__UsersTable').contains('Full Name donottouch').should('not.exist');
  })
});
