describe('Server details - dead server', () => {
  it('Server details - dead server', () => {
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.ServerLabelsHighlightingArea').contains(':13302').closest('li')
      .should('contain', 'Server status is "dead"')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdownBtn').contains('Server details').click();
    cy.get('.meta-test__ServerInfoModal').contains('Server status is "dead"');
    cy.get('.meta-test__ServerInfoModal button').contains('Cartridge').click();
    cy.get('.meta-test__ServerInfoModal button').contains('Replication').click();
    cy.get('.meta-test__ServerInfoModal button').contains('Storage').click();
    cy.get('.meta-test__ServerInfoModal button').contains('Network').click();
    cy.get('.meta-test__ServerInfoModal button').contains('General').click();
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
    cy.get('.meta-test__ServerInfoModal').contains('healthy');
    cy.get('.meta-test__ServerInfoModal').contains('instance_uuid');
    cy.get('.meta-test__ServerInfoModal').contains('bbbbbbbb-bbbb-0000-0000-000000000001');
    cy.get('.meta-test__ServerInfoModal button').contains('Close').click();
    cy.get('.ServerLabelsHighlightingArea').contains(':13302').closest('li')
      .contains('healthy');
  })
});
