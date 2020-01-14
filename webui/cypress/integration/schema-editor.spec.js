describe('Schema section', () => {
  it('Schema with bootstrap', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    const defaultText = '---\nspaces: []\n...\n';

    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/schema");
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    //Apply and Reload buttons
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Schema successfully applied');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('---\nspaces: []\n...\ntest error parsing');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains(
      'Error parsing section "schema.yml":' + 
      ' did not find expected <document start> at document');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').should('have.value', '');
    cy.get('.monaco-editor textarea').type('spaces: incorrect');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains(
      'Bad argument #1 to ddl.check_schema' +
      ' invalid schema.spaces (?table expected, got string)');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').should('have.value', '');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Unknown error at localhost');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    //Validate button
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('Schema is valid');
    
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('---\nspaces: []\n...\ntest error parsing');
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('did not find expected <document start> at document');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').should('have.value', '');
    cy.get('.monaco-editor textarea').type('spaces: incorrect');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect');
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains(
      'Bad argument #1 to ddl.check_schema' +
      ' invalid schema.spaces (?table expected, got string)');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').should('have.value', '');
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('attempt to index local \'err\' (a nil value)');
    
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

  });
});