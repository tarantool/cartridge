

describe('Login', () => {

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

  it('Login error', () => {
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('error')
      .should('have.value', 'error');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('Authentication failed');//try to found logout btn
    cy.get('.meta-test__LoginForm button[type="button"]').contains('Cancel').click();
  })

  it('Success login', () => {
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('{selectall}{del}')
      .type('admin')
      .should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LogoutBtn');//try to found logout btn
  })

  it('Logout', () => {
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();
  })

  it('Check login user with empty name', () => {
    cy.get('a[href="/admin/cluster/users"]').click();

    //create user without fullname:
    cy.get('.meta-test__addUserBtn').click();
    cy.get('.meta-test__UserAddForm input[name="username"]').type('testuser');
    cy.get('.meta-test__UserAddForm input[name="password"]').type('testpassword');
    cy.get('.meta-test__UserAddForm button:contains(Add)').click();

    //login user:
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]')
      .type('{selectall}{del}')
      .type('testuser');
    cy.get('.meta-test__LoginForm input[name="password"]')
      .type('testpassword');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LoginBtn').should('not.exist');
    cy.get('.meta-test__LogoutBtn');

    //logout and remove testuser:
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();

    cy.get('.meta-test__UsersTable li:contains(testuser)').find('button').click();
    cy.get('.meta-test__UsersTableItem__dropdown *').contains('Remove user').click();
    cy.get('.meta-test__UserRemoveModal button[type="button"]:contains(Remove)').click();
  })
});
