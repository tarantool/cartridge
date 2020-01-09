describe('Schema section', () => {
  it('Empty', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    const defaultText = '---\nspaces: []\n...\n';

    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/schema");
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    ////////////////////////////////////////////////////////////////////
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('spaces: incorrect-1');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect-1');

    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('Bad argument #1 to ddl.check_schema');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('spaces: [] # Essentially the same');

    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('Bad argument #1 to ddl.check_schema').should('not.exist');
    cy.get('#root').contains('Schema is valid');

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Schema successfully applied');

    ////////////////////////////////////////////////////////////////////
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('spaces: incorrect-2');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect-2');

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Bad argument #1 to ddl.check_schema');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: [] # Essentially the same');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type(defaultText);
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Bad argument #1 to ddl.check_schema').should('not.exist');
    cy.get('#root').contains('Schema successfully applied');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);
  });
});
