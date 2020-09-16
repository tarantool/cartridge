

describe('Detail server', () => {
  const testPort = `:13300`;

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

  it('Detail server', () => {
    cy.get('li').contains(testPort).closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Server details').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Cartridge').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Replication').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Storage').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('Network').click();
    cy.get('.meta-test__ServerInfoModal').find('button').contains('General').click();

  });

  it('You are here marker in server short info', () => {
    cy.get('.meta-test__ServerInfoModal').closest('div').find('.meta-test__youAreHereIcon');
  });

});
