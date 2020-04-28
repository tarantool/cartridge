describe('Code page', () => {

      before(function() {
            cy.visit(Cypress.config('baseUrl')+"/admin/cluster/code");
            cy.contains('Files');
          })

    it('Folder in tree', () => {
      function reload() {
            cy.get('.meta-test__Code__reload_idle').click();
            cy.get('button[type="button"]').contains('Ok').click();
            cy.get('.meta-test__Code__reload_loading').should('not.exist');
      }
      function apply() {
            cy.get('.meta-test__Code__apply_idle').click();
            cy.get('.meta-test__Code__apply_loading').should('not.exist');
      }

      //create folder
      cy.get('.meta-test__addFolderBtn').click();
      cy.get('.meta-test__enterName').focused().type('folder-in-tree');
      cy.get('#root').contains('Tarantool').click();
      cy.get('.meta-test__Code__FileTree').contains('folder-in-tree');

      //create folder in folder
      cy.get('.meta-test__createFolderInTreeBtn').click({ force: true });
      cy.get('.meta-test__enterName').focused().type('folder-in-folder{enter}');
      cy.get('.meta-test__Code__FileTree').contains('folder-in-folder');

      //create file in folder
      cy.get('.meta-test__createFileInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().type('file-in-folder{enter}');
      cy.get('.meta-test__Code__FileTree').contains('file-in-folder').click({ force: true });
      cy.get('.meta-test__Code').contains('folder-in-tree/file-in-folder');
      cy.get('.monaco-editor textarea').type('new test code');

      //edit folder name
      cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().clear().type('edited-folder-name{enter}');
      cy.get('.meta-test__Code__FileTree').contains('edited-folder-name');
      cy.get('.meta-test__Code__FileTree').contains('file-in-folder').should('be.visible');

      //save changes and full reload code page
      apply()
      cy.reload();
      cy.contains('Not loaded').should('not.exist');
      cy.get('.meta-test__Code__FileTree').contains('folder-in-folder').should('not.exist');
      cy.get('.meta-test__Code__FileTree').contains('file-in-folder').should('exist');
      cy.get('.meta-test__Code').contains('edited-folder-name/file-in-folder');
      cy.get('.monaco-editor textarea').should('have.value', 'new test code');

      //delete folder
      cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__deleteModal').should('be.visible');
      cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
      apply()
      cy.get('.meta-test__Code__FileTree').contains('edited-folder-name').should('not.exist');
    });
  });
