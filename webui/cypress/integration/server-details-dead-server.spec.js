describe('Server details - dead server', () => {
  it('Server details - dead server', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Server details').click(); 
    cy.get('.meta-test__ServerInfoModal').contains('Server status is "suspect"');
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Cartridge').click();
    cy.get('.meta-test__ServerInfoModal button[type="button"]').contains('Close').click();
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
  })
});