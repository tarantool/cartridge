

describe('Code page: empty', () => {

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
    cy.visit('/admin/cluster/code')
  });

  it('Empty code page', () => {
    const selectAllKeys = Cypress.platform == 'darwin' ? '{cmd}a' : '{ctrl}a';
    //const defaultText = 'Please select a file';

    cy.get('#root').contains('Please select a file');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied)').click();
  })

  it('Tab title on Code page', () => {
    cy.title().should('eq', 'cartridge-testing.r1: Code')
  })

  // it('Tab title on Code page on 8082', () => {
  //   cy.get('a[href="/admin/cluster/dashboard"]').click()
  //   cy.get('Cluster')
  //   cy.title().should('eq', 'cartridge-testing: Code')
  // })

});
