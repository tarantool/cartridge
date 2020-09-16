

describe('Code page: file in tree', () => {
    
      before(() => {
        cy.task('tarantool', {
          code: `
            cleanup()
            fio = require('fio')
            helpers = require('test.helper')
    
            local workdir = fio.tempdir()
            _G.cluster = helpers.Cluster:new({
              datadir = workdir,
              server_command = helpers.entrypoint('srv_basic'),
              use_vshard = true,
              cookie = 'test-cluster-cookie',
              env = {
                  TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
                  TARANTOOL_APP_NAME = 'cartridge-testing',
              },
              replicasets = {{
                alias = 'test-replicaset',
                uuid = helpers.uuid('a'),
                roles = {'vshard-router', 'vshard-storage', 'failover-coordinator'},
                servers = {{
                  alias = 'server1',
                  env = {TARANTOOL_INSTANCE_NAME = 'r1'},
                  instance_uuid = helpers.uuid('a', 'a', 1),
                  advertise_port = 13300,
                  http_port = 8080
                }}
              }}
            })
    
            _G.cluster:start()
            return _G.cluster.datadir
          `
        })
      });
    
      after(() => {
        cy.task('tarantool', {code: `cleanup()`});
      });
    
      it('Open WebUI', () => {
        cy.visit('/admin/cluster/code')
      });

    it('File in tree', () => {
      const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
      function reload() {
            cy.get('.meta-test__Code__reload_idle').click({force: true});
            cy.get('button[type="button"]').contains('Ok').click();
            cy.get('.meta-test__Code__reload_loading').should('not.exist');
      }
      function apply() {
            cy.get('.meta-test__Code__apply_idle').click({force: true});
            cy.get('.meta-test__Code__apply_loading').should('not.exist');
      }

      //create file and file contents
      cy.get('.meta-test__addFileBtn').click();
      cy.get('.meta-test__enterName').focused().type('file-in-tree1.yml');
      cy.get('#root').contains('cartridge-testing.r1').click();
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
      cy.wait(1000)
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
