describe('Schema section', () => {
  it('Empty', () => {
    const testText = `test code`;
    const assertText = testText.replace(' ', String.fromCharCode(160));

    cy.visit(Cypress.config('baseUrl'));
    cy.wait(500);
    cy.get('a[href="/admin/cluster/schema"]').click();
    cy.wait(1500);

    cy.get('.monaco-editor')
      .click().focused()
      .type('{meta}a')
      .type('{backspace}');

    cy.get('.monaco-editor')
      .click().focused()
      .type(testText);

    // это пока не работает
    cy.get('.monaco-editor .view-lines').invoke('text').then(text => cy.log(text.charCodeAt(4)));
    cy.log("cy.get('.monaco-editor .view-lines').text");

    cy.get('.monaco-editor .view-lines')
      .should('have.text', assertText);
    
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('Cluster isn\'t bootstrapped yet');
    cy.reload();
    cy.wait(500);
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Cluster isn\'t bootstrapped yet');
  });
});