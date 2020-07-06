/// <reference types="cypress" />

describe('Error details', () => {

  before(function () {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
  })

  function checksForErrorDetails(){
    cy.contains('Invalid cluster topology config');

    cy.get('button[type="button"]:contains(Copy details)').trigger('mouseover');
    cy.get('div').contains('Copy to clipboard');

    cy.get('button[type="button"]:contains(Copy details)').click();
    cy.get('div').contains('Copied');
    cy.get('div').contains('Copy to clipboard');

    cy.get('button[type="button"]').contains('Close').click();
    cy.contains('Invalid cluster topology config').should('not.exist');
  }

  it('Error details in notification', () => {
    cy.get('li').contains('router1-do-not-use-me').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('button[type="button"]:contains(Error details)').click();
    checksForErrorDetails();
  })

  it('Error details in notification list', () => {
    cy.get('button.meta-test__LoginBtn').parent('div').prev().click();
    cy.get('button[type="button"]:contains(Error details)').click();
    checksForErrorDetails();
  })

  it('Check Clear button in notification list', () => {
    cy.get('button.meta-test__LoginBtn').parent('div').prev().click();
    cy.get('button[type="button"]').contains('Clear').click();

    cy.get('button.meta-test__LoginBtn').parent('div').prev().click();
    cy.get('span').contains('No notifications');
  })

})
