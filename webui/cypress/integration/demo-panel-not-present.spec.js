import { find } from "ramda";

describe('Demo connection panel not exists', () => {
  it('On cluster page', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__ProbeServerBtn');
    cy.get('.meta-test__DemoInfo').should('not.exist');
  })

  it('On users page', () => {
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__DemoInfo').should('not.exist');
  })

  it('On config page', () => {
    cy.get('a[href="/admin/cluster/configuration"]').click();
    cy.get('.meta-test__DemoInfo').should('not.exist');
  })

  it('On editor page', () => {
    cy.get('a[href="/admin/cluster/code"]').click();
    cy.get('.meta-test__DemoInfo').should('not.exist');
  })

  it('On schema page', () => {
    cy.get('a[href="/admin/cluster/schema"]').click();
    cy.get('.meta-test__DemoInfo').should('not.exist');
  })
});