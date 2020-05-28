describe('Expel server', () => {

  it('Expel server', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(1).click();
    cy.get('li').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();

    cy.get('span:contains(Expel is OK. Please wait for list refresh...)').click();
  })

  it('Show expel error', () => {
    cy.reload();
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('li').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Cancel').click();
    cy.get('span:contains(An error has occurred)').click();

  })
});
