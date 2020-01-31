describe('Code page', () => {

    it('Folder in tree', () => {
      cy.visit(Cypress.config('baseUrl')+"/admin/cluster/code");
  //create folder
      cy.get('.meta-test__addFolderBtn').click();
      cy.get('.meta-test__enterName').focused().type('folder-in-tree');
      cy.get('#root').contains('Tarantool').click();
      cy.get('.ScrollbarsCustom-Content').contains('folder-in-tree');
  //create folder in folder
      cy.get('.meta-test__createFolderInTreeBtn').click({ force: true });
      cy.get('.meta-test__enterName').focused().type('folder-in-folder{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('folder-in-folder');
  //create file in folder
      cy.get('.meta-test__createFileInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().type('file-in-folder{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('file-in-folder').click();
      cy.get('#root').contains('folder-in-tree/file-in-folder');
      cy.get('.monaco-editor textarea').type('new test code');
  
  //edit folder name
      cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().clear().type('edited-folder-name{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('edited-folder-name').click();
  
  //save changes and full reload code page
      cy.get('button[type="button"]').contains('Apply').click();
      cy.reload();
      cy.get('#root').contains('edited-folder-name').click();
      cy.get('.ScrollbarsCustom-Content').contains('folder-in-folder').should('not.exist');
      cy.get('.ScrollbarsCustom-Content').contains('file-in-folder').click();
      cy.get('#root').contains('edited-folder-name/file-in-folder');
      cy.get('.monaco-editor textarea').should('have.value', 'new test code');
  
  //delete folder
      cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__deleteModal').should('be.visible');
      cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
      cy.get('button[type="button"]').contains('Apply').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-folder-name').should('not.exist');
    });
  });
  