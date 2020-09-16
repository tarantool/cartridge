

describe('Server details - dead server', () => {

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
              instance_uuid = helpers.uuid('b', 'b', 1),
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

  it('Server details - dead server', () => {
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8081 -t)', { failOnNonZeroExit: true });
    cy.get('.ServerLabelsHighlightingArea', { timeout: 6000 }).contains(':13301').closest('li')
      .should('contain', 'Server status is "dead"')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Server details').click();
    cy.get('.meta-test__ServerInfoModal').contains('Server status is "dead"');
    cy.get('.meta-test__ServerInfoModal button').contains('Cartridge').click();
    cy.get('.meta-test__ServerInfoModal button').contains('Replication').click();
    cy.get('.meta-test__ServerInfoModal button').contains('Storage').click();
    cy.get('.meta-test__ServerInfoModal button').contains('Network').click();
    cy.get('.meta-test__ServerInfoModal button').contains('General').click();
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8081 -t)', { failOnNonZeroExit: true });
    cy.get('.meta-test__ServerInfoModal').contains('healthy');
    cy.get('.meta-test__ServerInfoModal').contains('instance_uuid');
    cy.get('.meta-test__ServerInfoModal').contains('bbbbbbbb-bbbb-0000-0000-000000000001');
    cy.get('.meta-test__ServerInfoModal button').contains('Close').click();
    cy.get('.ServerLabelsHighlightingArea').contains(':13301').closest('li')
      .contains('healthy');
  })
});
