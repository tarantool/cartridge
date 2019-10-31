//Steps:
//Precondition: There is 1 configured server (not leader) in replica set
//1.Expel server
//      Open Expel dialog
//      Press the button Expel
//Precondition: There is 1 configured server (leader) in replica set
//2.Show expel error
//      Open Expel dialog
//      Try to expel leader
//      Show expel error

describe('Expel server', () => {

  it('press Escape for close dialog', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(1).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Expel server').click(); //need to change conteins later
    cy.get('.meta-test__ExpelServerModal').type('{esc}');
    cy.get('.meta-test__ExpelServerModal').should('not.exist');
  })

  it('press Enter in dialog', () => {
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(1).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Expel server').click(); //need to change conteins later
    cy.get('.meta-test__ExpelServerModal').type('{enter}');
    cy.get('.meta-test__ExpelServerModal').type('{esc}');
  })

  it('Expel server', () => {
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(1).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Expel server').click(); //need to change conteins later
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();

    cy.get('#root').contains('Expel is OK. Please wait for list refresh...');
  })

  it('Show expel error', () => {
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Expel server').click();//need to change conteins later
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Cancel').click();
    cy.get('#root').contains('An error has occurred');

  })
});