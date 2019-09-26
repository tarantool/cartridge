//Steps:
//1.Edit Replica Set
//      Press the button Edit
//      Clear old value in the field 'name of replica set' and fill a new value
//      Uncheck role: myrole
//      Press the button Save

describe('Edit Replica Set', () => {
  it('Edit Replica Set', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.contains('Edit').click();
    cy.get('.EditReplicasetModal input[name="alias"]')
      .type('{selectall}{del}')
      .type('editedRouter')
      .should('have.value', 'editedRouter');
    cy.get('.EditReplicasetModal input[type="checkbox"][value="myrole"]').uncheck({ force: true });

    cy.get('.EditReplicasetModal input[type="checkbox"][value="myrole"]').should('not.be.checked');
    cy.get('.EditReplicasetModal input[type="checkbox"][value="myrole-dependency"]').should('not.be.checked');
    cy.get('.EditReplicasetModal input[type="checkbox"][value="vshard-router"]').should('be.checked');
    cy.get('.EditReplicasetModal input[type="checkbox"][value="vshard-storage"]').should('not.be.checked');

    cy.get('.EditReplicasetModal button[type="submit"]').contains('Save').click();

    cy.get('#root').contains('editedRouter');
    cy.get('#root').contains('Edit is OK. Please wait for list refresh...');
  })
});