

describe('Schema section', () => {

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
    cy.visit('/admin/cluster/schema')
  });

  it('Schema with bootstrap', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    const defaultText = '---\nspaces: []\n...\n';

    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    ////////////////////////////////////////////////////////////////////
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('spaces: incorrect-1');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect-1');

    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('Schema.spaces must be a ?table, got string');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('spaces: [] # Essentially the same');

    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('Bad argument #1 to ddl.check_schema').should('not.exist');
    cy.get('#root').contains('Schema is valid');

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('span:contains(Success) + span:contains(Schema successfully applied)').click();

    ////////////////////////////////////////////////////////////////////
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('spaces: incorrect-2');
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: incorrect-2');

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Schema.spaces must be a ?table, got string');

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', 'spaces: [] # Essentially the same');

    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type(defaultText);
    cy.get('.monaco-editor textarea').should('have.value', defaultText);

    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('#root').contains('Bad argument #1 to ddl.check_schema').should('not.exist');
    cy.get('span:contains(Success) + span:contains(Schema successfully applied)').click();

    cy.get('button[type="button"]').contains('Reload').click();
    cy.get('.monaco-editor textarea').should('have.value', defaultText);
  })

  it('Tab title on Schema page', () => {
    cy.title().should('eq', 'cartridge-testing.r1: Schema')
  })

});
