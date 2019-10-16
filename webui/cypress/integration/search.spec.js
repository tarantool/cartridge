//Steps:
//1.Search
describe('Probe server', () => {
  it('opens probe dialog', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__Filter input[placeholder="Filter by uri, uuid, role, alias or labels"]')
      .type('storage1-do-not-use-me')
      .should('have.value', 'storage1-do-not-use-me');
    cy.get('li').contains('storage1-do-not-use-me');
  })
});