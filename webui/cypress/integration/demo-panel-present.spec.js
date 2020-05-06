import { find } from "ramda";

describe('Demo connection panel exists', () => {
  it('On cluster page', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__DemoInfo').contains('Your demo server is created. Temporary address of you server:');
    cy.get('.meta-test__DemoInfo button[type="button"]:contains(How to connect?)').click();
    cy.get('.meta-test__DemoInfo_modal').contains('Connect to Tarantool Cartridge using python client');
    cy.get('.meta-test__DemoInfo_modal button:contains(PHP)').click();
    cy.get('.meta-test__DemoInfo_modal').contains('Connect to Tarantool Cartridge using PHP client');
    cy.get('.meta-test__DemoInfo_modal button:contains(Close)').click();
  })

  it('On users page', () => {
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__DemoInfo').should('be.visible');
  })

  it('On config page', () => {
    cy.get('a[href="/admin/cluster/configuration"]').click();
    cy.get('.meta-test__DemoInfo').should('be.visible');
  })

  it('On editor page', () => {
    cy.get('a[href="/admin/cluster/code"]').click();
    cy.get('.meta-test__DemoInfo').should('be.visible');
  })

  it('On schema page', () => {
    cy.get('a[href="/admin/cluster/schema"]').click();
    cy.get('.meta-test__DemoInfo').should('be.visible');

    cy.get('.meta-test__DemoInfo button[type="button"]:contains(Reset configuration)').click();
    cy.get('div:contains(Do you really want to reset your settings?)').find('button:contains(Reset)').click();
    cy.location().should((loc) => {
      // expect(loc.search).to.eq('?flush_session=1'); // непонятно как проверить несколько редиректов под ряд
      expect(loc.pathname).to.eq('/admin/cluster/dashboard');
    });
  })
});
