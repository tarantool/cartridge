

describe('Replicaset configuration & Bootstrap Vshard', () => {

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
      
      _G.server = helpers.Server:new({
            workdir = workdir.."/spare",
            alias = 'spare',
            command = helpers.entrypoint('srv_basic'),
            replicaset_uuid = helpers.uuid('с'),
            instance_uuid = helpers.uuid('b', 'b', 3),
            http_port = 8081,
            cluster_cookie = _G.cluster.cookie,
            advertise_port = 13301,
            env = {
                TARANTOOL_WEBUI_BLACKLIST = '/cluster/configuration',
                TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 1,
            },
        })
        _G.cluster:start()
        _G.server:start()
        return true
      `
    }).should('deep.eq', [true])

  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard')
  });

  it('1. Create replicaset dialog', () => {
    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList

    // I. Invalid alias
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type(' ');
    cy.get('.meta-test__ConfigureServerModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.disabled');

    // II. Fix alias
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__ConfigureServerModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -').should('not.exist');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // III. Select all roles
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('test-replicaset');
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click();

    // IV. Invalid weight
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('q');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.disabled');

    // V. Fix weight
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('{selectall}{backspace}').type('1.0');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').type('{enter}');
    cy.get('.meta-test__ConfigureServerModal').should('not.exist');

  })

  it('2. Probe server dialog',() => {
    cy.get('.meta-test__ProbeServerBtn').click();

    // I. Invalid uri
    cy.get('.ProbeServerModal input[name="uri"]')
      .type(' ');
    cy.get('.meta-test__ProbeServerSubmitBtn').click();
    cy.get('.ProbeServerModal_error').contains('Probe " " failed: parse error');

    // II. Fix uri
    cy.get('.ProbeServerModal input[name="uri"]')
      .type('{selectall}localhost:13300{enter}');
    cy.get('.ProbeServerModal').should('not.exist');
    cy.get('span:contains(Probe is OK)').click();
  })

  it('3. Edit replicaset dialog',() => {
    cy.get('li').contains('test-replicaset').closest('li').find('button').contains('Edit').click({ force: true });

    // I.
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type(' ');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');

    // II.
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');

    // III.
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]')
      .type('q');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');

    // IV.
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');

    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
  })

it('4. Add user dialog',() => {
    cy.get('a[href="/admin/cluster/users"]').click({ force: true });
    cy.get('.meta-test__addUserBtn').click({ force: true }); //webui/src/pages/Users/index.js
    cy.get('.meta-test__UserAddForm input[name="email"]')
      .type('not_valid');
    cy.get('.meta-test__UserAddForm input[name="username"]').focus();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email');

    cy.get('.meta-test__UserAddForm input[name="email"]')
      .type('qq@qq.qq');
    cy.get('.meta-test__UserAddForm input[name="password"]').focus();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email').should('not.exist');

    cy.get('.meta-test__UserAddForm input[name="username"]')
      .type('username');
    cy.get('.meta-test__UserAddForm input[name="password"]')
      .type('qwerty{enter}');
    cy.get('.meta-test__UserAddForm').should('not.exist');
  })

});
