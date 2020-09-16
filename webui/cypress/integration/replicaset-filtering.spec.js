

describe('Replicaset filtering', () => {
  const testPort4 = `:13304`;
  const localhost10 = `localhost:13305`;

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
            alias = 'router1-do-not-use-me',
            uuid = helpers.uuid('a'),
            roles = {'vshard-router'},
            servers = {{
              alias = 'router',
              env = {TARANTOOL_INSTANCE_NAME = 'r1'},
              instance_uuid = helpers.uuid('a', 'a', 1),
              advertise_port = 13300,
              http_port = 8080
            }}
          }, {
            alias = 'storage1-do-not-use-me',
            uuid = helpers.uuid('b'),
            roles = {'vshard-storage', 'failover-coordinator'},
            servers = {{
              alias = 'storage',
              instance_uuid = helpers.uuid('b', 'b', 1),
              advertise_port = 13302,
              http_port = 8082
            }, {
              alias = 'storage-2',
              instance_uuid = helpers.uuid('b', 'b', 2),
              advertise_port = 13304,
              http_port = 8084
            }}
          }}
        })

        _G.server = helpers.Server:new({
            workdir = workdir.."/spare",
            alias = 'spare',
            command = helpers.entrypoint('srv_basic'),
            replicaset_uuid = helpers.uuid('с'),
            instance_uuid = helpers.uuid('b', 'b', 3),
            http_port = 8085,
            cluster_cookie = _G.cluster.cookie,
            advertise_port = 13305,
            env = {TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 1},
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

  it('Tab title on Cluster page', () => {
    cy.title().should('eq', 'cartridge-testing.r1: Cluster')
  })

  it('Stop servers', () => {
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8084 -t)', { failOnNonZeroExit: true });
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
  })

  it('Filter in replicaset list', () => {
    cy.reload();
    cy.contains('Replica sets', { timeout: 8000 });

    //Healthy
    cy.get('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Healthy)').click();
    cy.get('.meta-test__Filter input').should('have.value', 'status:healthy');
    cy.get('.ServerLabelsHighlightingArea').contains(testPort4).should('not.exist');

    //Unhealthy
    cy.get('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Unhealthy)').click();
    cy.get('.meta-test__Filter input').should('have.value', 'status:unhealthy');
    cy.get('.ServerLabelsHighlightingArea').contains(testPort4);

    //Role
    cy.get('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown').find('*:contains(vshard-storage)').click();
    cy.get('.meta-test__Filter input').should('have.value', 'role:vshard-storage');
    cy.get('.ServerLabelsHighlightingArea').contains(testPort4);
    cy.get('#root').contains('storage1-do-not-use-me');
    cy.get('#root').contains('router1-do-not-use-me').should('not.exist');

    //Clear filter
    cy.get('.meta-test__Filter svg').eq(1).click();

    //Search
    cy.get('.meta-test__Filter').find('input').type(testPort4);
    cy.get('#root').contains('storage1-do-not-use-me');
    cy.get('#root').contains('router1-do-not-use-me').should('not.exist');
  })

  it('Filter in join replicaset dialog', () => {

    cy.get('li').contains(localhost10).closest('li').find('button')
      .contains('Configure').click();
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();

    //Healthy
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Healthy)').click();
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input')
      .should('have.value', 'status:healthy');
    cy.get('.meta-test__ConfigureServerModal').contains('storage1-do-not-use-me')
      .should('not.exist');

    // //Unhealthy
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Unhealthy)').click();
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input')
      .should('have.value', 'status:unhealthy');
    cy.get('.meta-test__ConfigureServerModal').contains('router1-do-not-use-me')
      .should('not.exist');

    // //Role
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(vshard-router)').click();
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input')
      .should('have.value', 'role:vshard-router');
    cy.get('.meta-test__ConfigureServerModal').contains('storage1-do-not-use-me')
      .should('not.exist');

    //Clear filter
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter svg').eq(1).click();

    // //Search
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter').find('input')
      .type('storage1-do-not-use-me');
    cy.get('.meta-test__ConfigureServerModal').contains('storage1-do-not-use-me');
    cy.get('.meta-test__ConfigureServerModal').contains('router1-do-not-use-me').should('not.exist');

    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Cancel)').click();
  })

  it('Rusurrect servers', () => {
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8084 -t)', { failOnNonZeroExit: true });
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
  })

})
