//Steps:
//1.Probe server
//      Open probe dialog
//      Enter the unreachable value -> Error
//      Enter the correct value ->Success
//      Press escape for close dialog
//      press Enter in Probe dialog

describe('Probe server', () => {
  it('opens probe dialog', () => {
    cy.visit(Cypress.config('baseUrl'));

    cy.get('.meta-test__ProbeServerBtn').click(); //component:ProbeServerModal
  });

  it('shows probing error', () => {
    cy.get('.ProbeServerModal input[name="uri"]')
      .type('unreachable')
      .should('have.value', 'unreachable');

    cy.get('.meta-test__ProbeServerSubmitBtn').click();//component:ProbeServerModal

    cy.get('.ProbeServerModal_error').contains('Probe "unreachable" failed: ping was not sent');
  });

  it('shows probings success message', () => {
    cy.get('.ProbeServerModal input[name="uri"]')
      .clear()
      .type('localhost:13302')
      .should('have.value', 'localhost:13302');

    cy.get('.meta-test__ProbeServerSubmitBtn').click();

    cy.get('#root').contains('Probe is OK. Please wait for list refresh...');//add to frontend-core classname for notification
  })

  it('press Escape for close dialog', () => {
    cy.get('.meta-test__ProbeServerBtn').click(); //component:ProbeServerModal
    cy.get('.ProbeServerModal').type('{esc}');
    cy.get('.ProbeServerModal').should('not.exist');
  })

  it('press Enter in Probe dialog', () => {
    cy.get('.meta-test__ProbeServerBtn').click(); //component:ProbeServerModal
    cy.get('.ProbeServerModal input[name="uri"]').type('{enter}');
    cy.get('.ProbeServerModal_error').contains('Probe "" failed: parse error');
  })

});
