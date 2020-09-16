

describe('Expel server', () => {

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
            }, {
              alias = 'server2',
              instance_uuid = helpers.uuid('b', 'b', 2),
              advertise_port = 13301,
              http_port = 8081
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


  it('Expel server', () => {
    cy.get('li').contains('test-replicaset').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(1).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();

    cy.get('span:contains(Expel is OK. Please wait for list refresh...)').click();
  })

  it('Show expel error', () => {
    cy.reload();
    cy.get('li').contains('test-replicaset').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('span:contains(Current instance "localhost:13300" can not be expelled)').click();

  })
});
