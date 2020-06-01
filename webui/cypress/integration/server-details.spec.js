const testPort = `:13301`;

describe('Detail server', () => {

  before(function () {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
  });

  it('Detail server', () => {
    cy.get('li').contains(testPort).closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Server details').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Cartridge').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Replication').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Storage').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Network').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('General').click();

  });

  it('You are here marker in server short info', () => {
    cy.get('.meta-test__ServerInfoModal').closest('div').find('.meta-test__youAreHereIcon');
  });

});
