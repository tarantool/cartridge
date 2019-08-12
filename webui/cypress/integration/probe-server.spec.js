describe('Probe server', () => {
  it('starts tarantool', () => {
    cy.task('refreshTarantool');
  });

  it('opens probe dialog', () => {
    cy.visit(Cypress.env('CYPRESS_BASE_URL'));

    cy.contains('Probe server').click();
  });

  it('shows probing error', () => {
    cy.get('.ant-modal .ant-input')
      .type('unreachable')
      .should('have.value', 'unreachable');

    cy.get('.ant-modal button.ant-btn[type=button]').click();

    cy.get('.ant-modal').contains('Probe "unreachable" failed: ping was not sent');
  });

  it('shows probings success message', () => {
    cy.get('.ant-modal .ant-input')
      .clear()
      .type('localhost:3304')
      .should('have.value', 'localhost:3304');

    cy.get('.ant-modal button.ant-btn[type=button]').click();

    cy.get('.ant-notification-notice').contains('Probe is OK. Please wait for list refresh...');
  })

  it('stops and cleans tarantool', () => {
    cy.task('wipeTarantool');
  });
});
