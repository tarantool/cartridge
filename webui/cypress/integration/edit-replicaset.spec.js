

describe('Edit Replica Set', () => {

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
    cy.visit('/admin/cluster/dashboard')
  });

  it('Edit Replica Set', () => {
    cy.get('li').contains('test-replicaset').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type('{selectall}editedRouter')
      .should('have.value', 'editedRouter');
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="myrole"]').uncheck({ force: true });

    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="myrole"]')
      .should('not.be.checked')
      .should('not.be.checked');

    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]')
      .uncheck({ force: true })
      .should('not.be.checked');

    cy.get('.meta-test__EditReplicasetSaveBtn').click();

    cy.get('#root').contains('editedRouter').closest('li').find('.meta-test__ReplicasetList_allRw_enabled').should('not.exist');
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();
  })
});
