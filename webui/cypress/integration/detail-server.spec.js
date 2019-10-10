//Steps:
//Precondition: There is 1 configured server (not leader) in replica set
//1.Open detail server menu
// Tab to General,
// Tab to Replication,
// Tab to Storage,
// Close detail server menu

describe('Detail server', () => {
  it('Detail server', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Server details').click(); //need to change conteins later
    cy.get('.meta-test__ServerInfoModal').find('button').contains('General').click(); //need to change conteins later
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Replication').click(); //need to change conteins later
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Storage').click(); //need to change conteins later
  })
});