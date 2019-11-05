//Steps:
//1.Edit Replica Set
//      Press the button Edit
//      Clear old value in the field 'name of replica set' and fill a new value
//      Uncheck role: myrole
//      Press the button Save
//      press Escape for close dialog
//      press Enter in dialog

describe('Edit Replica Set', () => {
  it('Edit Replica Set', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('li').contains('router1-do-not-use-me').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type('{selectall}editedRouter')
      .should('have.value', 'editedRouter');
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="myrole"]').uncheck({ force: true });

    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="myrole"]').should('not.be.checked');
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="myrole-dependency"]').should('not.be.checked');

    cy.get('.meta-test__EditReplicasetSaveBtn').click();//component:EditReplicasetForm

    cy.get('#root').contains('editedRouter');
    cy.get('#root').contains('Edit is OK. Please wait for list refresh...'); //add to frontend-core classname for notification
  })

  it('press Escape for close dialog', () => {
    cy.get('li').contains('editedRouter').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal').type('{esc}');
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
  })

  it('press Enter in dialog', () => {
    cy.get('li').contains('editedRouter').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]').type('{enter}');
    cy.get('#root').contains('Edit is OK. Please wait for list refresh...'); //add to frontend-core classname for notification
  })
});