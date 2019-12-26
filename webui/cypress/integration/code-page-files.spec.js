describe('Code page: files', () => {
  it('Folder in tree', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.wait(600);
//create folder
    cy.get('a[href="/admin/cluster/code"]').click();
    cy.wait(600);
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
    cy.get('.ScrollbarsCustom-Content').contains('file-in-folder');
//edit folder name
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-folder-name{enter}');
    cy.get('.ScrollbarsCustom-Content').contains('edited-folder-name').click();
//delete folder (it does not have files)
    cy.get('.meta-test__deleteFolderInTreeBtn').eq(1).click({ force: true });
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('.ScrollbarsCustom-Content').contains('folder-in-folder').should('not.exist');
//delete folder (it has files)
    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('.ScrollbarsCustom-Content').contains('folder-in-tree').should('not.exist');
  });

  it('File in tree', () => {
//create file
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree{enter}');
    cy.get('.ScrollbarsCustom-Content').contains('file-in-tree');
//edit file name
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-file-name{enter}');
    cy.get('.ScrollbarsCustom-Content').contains('edited-file-name').click();
//delete file
    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('.ScrollbarsCustom-Content').contains('folder-in-tree').should('not.exist');
  })
});