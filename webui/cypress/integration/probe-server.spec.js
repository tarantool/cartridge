describe('Probe server', () => {
  it('opens probe dialog', () => {
    cy.visit(Cypress.config('baseUrl'));

    cy.contains('Probe server').click();
  });

  it('shows probing error', () => {
    cy.get('.ProbeServerModal input[name="uri"]')
      .type('unreachable')
      .should('have.value', 'unreachable');

    cy.get('.ProbeServerModal button[type=submit]').click();

    cy.get('.ProbeServerModal_error').contains('Probe "unreachable" failed: ping was not sent');
  });

  it('shows probings success message', () => {
    cy.get('.ProbeServerModal input[name="uri"]')
      .clear()
      .type('localhost:33002')
      .should('have.value', 'localhost:33002');

    cy.get('.ProbeServerModal button[type=submit]').click();

    cy.get('.ant-notification-notice').contains('Probe is OK. Please wait for list refresh...');
  })
});
