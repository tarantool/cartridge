describe('Schema section', () => {
  it('Schema without bootstrap', () => {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/schema");

    cy.get('button[type="button"]:contains("Validate")').click();
    cy.get('#root').contains('Cluster isn\'t bootstrapped yet');

    cy.get('button[type="button"]:contains("Reload")').click();
    cy.get('.monaco-editor textarea').should('have.value', '');

    cy.get('button[type="button"]:contains("Apply")').click();
    cy.get('#root').contains('Cluster isn\'t bootstrapped yet');
  })

  it('Try to add user without bootstrap', () => {
    cy.get('a[href="/admin/cluster/users"]').click();

    cy.get('.meta-test__addUserBtn').click({ force: true });
    cy.get('.meta-test__UserAddForm input[name="username"]')
      .type('unitialisedUser');
    cy.get('.meta-test__UserAddForm input[name="password"]')
      .type('123');
    cy.get('.meta-test__UserAddForm button[type="submit"]').contains('Add').click();
    cy.get('.meta-test__UserAddForm')
      .contains('Topology not specified, seems that cluster isn\'t bootstrapped');
    cy.get('.meta-test__UserAddForm button[type="button"]').contains('Cancel').click();
    cy.get('.meta-test__UsersTable').contains('unitialisedUser').should('not.exist');
  })

});
