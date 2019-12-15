describe('Code page: lsp', () => {

      it('Text color', () => {

            cy.visit(Cypress.config('baseUrl') + "/admin/cluster/code");
            cy.get('.meta-test__addFileBtn').click();
            cy.get('.meta-test__enterName').focused().type('test-code.lua{enter}');
            cy.get('.ScrollbarsCustom-Content').contains('test-code.lua').click();
            cy.get('.monaco-editor textarea').type("local json = require( 'json');\n");
            cy.get('.mtk19').should('have.css', 'color', 'rgb(32, 96, 160)');
            cy.get('.mtk30').should('have.css', 'color', 'rgb(192, 48, 48)');
      });

      it('Tooltip for selecting an object and Read more/less information', () => {
            cy.get('.monaco-editor textarea').type('js');

            //open Read more
            cy.get('.monaco-editor textarea').type('{ctrl} ');
            cy.get('.type').contains('M<json>');
            //open Read less
            cy.get('.monaco-editor textarea').type('{ctrl} ');
            cy.get('.type').contains('M<json>').should('not.be.visible');

            cy.get('.monaco-highlighted-label').click();
            cy.get('.monaco-editor textarea').should('have.value', "local json = require( 'json');\njson");
      });

      it('Method selection', () => {
            cy.get('.monaco-editor textarea').type(".");
            cy.get('.monaco-highlighted-label');
            cy.get('span[class="monaco-highlighted-label"]').contains('cfg()').click();
            cy.get('.monaco-editor textarea').should('have.value', "local json = require( 'json');\njson.cfg()");
      });

      it('Description for text in Code', () => {
            cy.get('.monaco-editor-hover').should('not.be.visible');
            cy.get('.monaco-editor textarea')
                  .type("{leftarrow}{leftarrow}{leftarrow}{leftarrow}")
                  .type("{ctrl}k{ctrl}i");
            cy.get('.monaco-editor-hover').should('be.visible');
      });

      it('LSP connection is not interrupted after 2 minutes', () => {
            cy.get('.monaco-editor textarea').type("{del}{del}{del}{del}");
            cy.get('.monaco-editor textarea').type("f");
            cy.get('span[class="monaco-highlighted-label"]').should('be.visible');
            cy.get('.monaco-editor textarea').type("{backspace}{backspace}{backspace}");

            cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :13301 -t)', { failOnNonZeroExit: true });
            cy.get('.monaco-editor textarea').type(".");
            cy.get('span[class="monaco-highlighted-label"]').should('not.be.visible');

            cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :13301 -t)', { failOnNonZeroExit: true });
            cy.get('.monaco-editor textarea').type("c");
            cy.get('span[class="monaco-highlighted-label"]').should('be.visible');

      });
});
