describe('Code page', () => {

    it('File in tree', () => {
      const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
      function reload() {
            cy.get('.meta-test__Code__reload_idle').click();
            cy.get('button[type="button"]').contains('Ok').click();
            cy.get('.meta-test__Code__reload_loading').should('not.exist');
      }
      function apply() {
            cy.get('.meta-test__Code__apply_idle').click();
            cy.get('.meta-test__Code__apply_loading').should('not.exist');
      }

      cy.visit(Cypress.config('baseUrl')+"/admin/cluster/code");

      //create file and file contents
      cy.get('.meta-test__addFileBtn').click();
      cy.get('.meta-test__enterName').focused().type('file-in-tree1.yml');
      cy.get('.test__Header').click();
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree1.yml');

      //reload
      reload()
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree1.yml').should('not.exist');

      //apply
      cy.get('.meta-test__addFileBtn').click();
      cy.get('.meta-test__enterName').focused().type('file-in-tree2.yml{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml');
      apply()
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml');
      reload()
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml');

      //file contents
      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('some test code');

      //check for page change
      cy.get('a[href="/admin/cluster/dashboard"]').click();
      cy.get('a[href="/admin/cluster/code"]').click();
      cy.get('.monaco-editor textarea').should('have.value', 'some test code');

      reload()
      cy.get('.monaco-editor textarea').should('have.value', '');

      cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2.yml').click();
      cy.get('.monaco-editor textarea').type('some test code2');
      apply()
      reload()
      cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

      // wrong yaml error
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('some: [] test code2');
      apply()
      cy.get('#root').contains('LoadConfigError: Error parsing section "file-in-tree2.yml": did not find expected key at document');
      reload()
      cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

      //edit file and file contents
      cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().clear().type('edited-file-name{enter}');
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name');

      //reload
      reload()
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name').should('not.exist');

      //apply
      cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__enterName').focused().clear().type('edited-file-name2{enter}');
      apply()
      reload()
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();

      //file contents
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('edit test code');
      cy.get('.monaco-editor textarea').should('have.value', 'edit test code');

      reload()
      cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('edit test code2');
      apply()
      reload()
      cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');

      //delete file and file contents
       //file contents
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      cy.get('.monaco-editor textarea').type('a{backspace}'); //без этого не работает
      cy.get('.monaco-editor textarea').should('have.value', '');

      reload()
      cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');

      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
      cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
      apply()
      reload()
      cy.get('.monaco-editor textarea').should('have.value', '');

      //reload
      cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').should('not.exist');
      reload()
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2');

      //apply
      cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
      cy.get('.meta-test__deleteModal').should('be.visible');
      cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
      apply()
      reload()
      cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').should('not.exist');
    });
});
