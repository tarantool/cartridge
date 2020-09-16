

describe('Code page: folder in tree', () => {
    
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
      cy.get('#root').contains('cartridge-testing.r1').click();
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
