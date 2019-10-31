//Steps:
//1.Failover
//      Open probe dialog
//      Failover turn on
//      Failover turn off

describe('Failover', () => {
  it('Failover turn on', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__FailoverSwitcherBtn').contains('Failover').click();//component:ClusterButtonsPanel
    cy.get('.meta-test__FailoverControlBtn').click();//component: FailoverButton
    cy.get('#root').contains('Failover change is OK...');//add to frontend-core classname for notification
  })

  it('Failover turn off', () => {
    cy.get('.meta-test__FailoverSwitcherBtn').contains('Failover').click();//component:ClusterButtonsPanel
    cy.get('.meta-test__FailoverControlBtn').click();//component: FailoverButton
    cy.get('#root').contains('Failover change is OK...');//add to frontend-core classname for notification
  })

  it('press Escape for close dialog', () => {
    cy.get('.meta-test__FailoverSwitcherBtn').contains('Failover').click();//component:ClusterButtonsPanel
    cy.get('.meta-test__FailoverControl').type('{esc}');
    cy.get('.meta-test__FailoverControl').should('not.exist');
  })
    
  it('press Enter in Probe dialog', () => {
    cy.get('.meta-test__FailoverSwitcherBtn').contains('Failover').click();//component:ClusterButtonsPanel
    cy.get('.meta-test__FailoverControl').type('{enter}');
    cy.get('.meta-test__FailoverControl');
  })
    
});