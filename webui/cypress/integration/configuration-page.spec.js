//Steps:
//1. Download configuration file
//import 'cypress-file-upload'; for upload, do it later

describe('Download configuration file', () => {

  it('Tab title on Configuration files page', () => {
    cy.get('head title').should('contain', 'cartridge.srv-1: Configuration files')
  })

  it('Download configuration file', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('a[href="/admin/cluster/configuration"]').click();
    //cy.get('button[type="submit]').contains('Download').click();
    cy.get('.meta-test__DownloadBtn').click(); //webui/src/pages/ConfigManagement/ConfigManagement.js
/*     const fileName = 'config.yml'; for upload, do it later
    cy.fixture(fileName).then(fileContent => {
      cy.get('[data-cy="file-input"]').upload({ fileContent, fileName, mimeType: 'application/json' });
    }); */
  })

});
