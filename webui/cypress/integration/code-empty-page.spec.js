describe('Code page', () => {

  it('Empty code page', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    //const defaultText = 'Please select a file';

    cy.visit(Cypress.config('baseUrl')+'/admin/cluster/code');
    cy.get('#root').contains('Please select a file');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied)').click();
  })

  it('Tab title on Code page', () => {
    cy.title().should('eq', 'cartridge-testing.r1: Code')
  })

  it('Tab title on Code page on 8082', () => {
    cy.visit('http://localhost:8082/admin/cluster/code');
    cy.title().should('eq', 'cartridge-testing: Code')
  })

});
