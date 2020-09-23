

describe('Probe server', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()
      fio = require('fio')
      helpers = require('test.helper')

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
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

  it('opens probe dialog', () => {
    cy.contains('cartridge-testing.r1'); //check application name
    cy.get('.meta-test__ProbeServerBtn').click();
  });

  it('shows probing error', () => {
    cy.get('.ProbeServerModal input[name="uri"]')
    .type('unreachable')
    .should('have.value', 'unreachable');

    cy.get('.meta-test__ProbeServerSubmitBtn').click();

    cy.get('.ProbeServerModal_error').contains('Probe "unreachable" failed: ping was not sent');
  });

  it('shows probings success message', () => {
    cy.get('.ProbeServerModal input[name="uri"]')
    .clear()
    .type('localhost:13301')
    .should('have.value', 'localhost:13301');

    cy.get('.meta-test__ProbeServerSubmitBtn').click();

    cy.get('span:contains(Probe is OK. Please wait for list refresh...)').click();
  })

  it('press Escape for close dialog', () => {
    cy.get('.meta-test__ProbeServerBtn').click();
    cy.get('.ProbeServerModal').type('{esc}');
    cy.get('.ProbeServerModal').should('not.exist');
  })

  it('press Enter in Probe dialog', () => {
    cy.get('.meta-test__ProbeServerBtn').click();
    cy.get('.ProbeServerModal input[name="uri"]').type('{enter}');
    cy.get('.ProbeServerModal_error').contains('Probe "" failed: parse error');
  })
});
