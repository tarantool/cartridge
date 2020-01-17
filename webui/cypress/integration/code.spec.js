describe('Code page: files', () => {

  it('Empty code page', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    const defaultText = 'Select or add a file';

    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/code");
    cy.get('.monaco-editor textarea').should('have.value', defaultText);
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Files successfuly applied');
  });

it('File in tree', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';

//create file and file contents
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree1{enter}');
    cy.get('.ScrollbarsCustom-Content').contains('file-in-tree1');
    //reload
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.ScrollbarsCustom-Content').contains('file-in-tree1').should('not.exist');
    //apply
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree2{enter}');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2');
    //file contents
    cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('some test code');
    cy.get('.monaco-editor textarea').should('have.value', 'some test code');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', '');

    cy.get('.ScrollbarsCustom-Content').contains('file-in-tree2').click();
    cy.get('.monaco-editor textarea').type('some test code2');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

//edit file and file contents
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-file-name{enter}');
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name').click();
    //reload
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name').should('not.exist');
    //apply
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-file-name2{enter}');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
     //file contents
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('edit test code');
    cy.get('.monaco-editor textarea').should('have.value', 'edit test code');
 
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', 'some test code2');
 
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('edit test code2');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');   

//delete file and file contents
     //file contents
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').should('have.value', '');
 
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');
 
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', '');
    //reload
    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').should('not.exist');
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2');
    //apply
    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name2').should('not.exist');
     });

  it('Folder in tree', () => {
//create folder
    cy.get('.meta-test__addFolderBtn').click();
    cy.get('.meta-test__enterName').focused().type('folder-in-tree{enter}');
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
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('.ScrollbarsCustom-Content').contains('edited-folder-name').should('not.exist');
  });
});
