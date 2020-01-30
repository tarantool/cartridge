describe('Code page', () => {

    it('File in tree', () => {
      const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
  
      cy.visit(Cypress.config('baseUrl')+"/admin/cluster/code");

  //create file and file contents
      cy.get('.meta-test__addFileBtn').click();
      cy.get('.meta-test__enterName').focused().type('file-in-tree{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree');
      //reload
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree').should('not.exist');
      //apply
      cy.get('.meta-test__addFileBtn').click();
      cy.get('.meta-test__enterName').focused().type('file-in-tree2.yml{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml');
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      //file contents
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('some test code');
          //check for page change
      cy.get('a[href="/admin/cluster/dashboard"]').click();
      cy.get('a[href="/admin/cluster/code"]').click();
      cy.get('.monaco-editor textarea').should('have.value', 'some test code');
  
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', '');
  
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml').click();
      cy.get('.monaco-editor textarea').type('some test code2');
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', 'some test code2');
      // wrong yaml error
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('some: [] test code2');
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('#root').contains('GraphQL error: Error parsing section "file-in-tree2.yml": did not find expected key at document');
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', 'some test code2');
  
  //edit file and file contents
      cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().clear().type('edited-file-name{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name');
      //reload
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name').should('not.exist');
      //apply
      cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().clear().type('edited-file-name2{enter}');
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
       //file contents
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('edit test code');
      cy.get('.monaco-editor textarea').should('have.value', 'edit test code');
   
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('edit test code2');
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');   
  
  //delete file and file contents
       //file contents
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('a{backspace}'); //без этого не работает
      cy.get('.monaco-editor textarea').should('have.value', '');
   
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');

      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.monaco-editor textarea').should('have.value', '');
      //reload
      cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').should('not.exist');
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2');
      //apply
      cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__deleteModal').should('be.visible');
      cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('button[type="button"]').contains('Reload').click();
      cy.get('button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').should('not.exist');
    });
});
  