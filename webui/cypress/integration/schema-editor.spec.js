describe('Schema section', () => {
  it('Empty', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    const defaultText = '---\nspaces: []\n...\n';

    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/schema");
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').should('have.value', '');
    cy.get('.monaco-editor textarea').type('spaces: incorrect');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect');

    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains(
      'Bad argument #1 to ddl.check_schema' +
      ' invalid schema.spaces (?table expected, got string)');

    cy.reload();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Schema successfully applied');
  });
});
