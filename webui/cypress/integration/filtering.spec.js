describe('Replicaset filtering', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),

        env = {TARANTOOL_APP_NAME = 'cartridge-testing'},
        replicasets = {{
          uuid = helpers.uuid('a'),
          alias = 'test-router',
          roles = {'vshard-router', 'failover-coordinator'},
          servers = {{http_port = 8080}},
        }, {
          uuid = helpers.uuid('b'),
          alias = 'test-storage',
          roles = {'vshard-storage'},
          servers = 2,
        }}
      })

      _G.server = helpers.Server:new({
          alias = 'spare',
          workdir = fio.tempdir(),
          command = helpers.entrypoint('srv_basic'),
          replicaset_uuid = helpers.uuid('b'),
          instance_uuid = helpers.uuid('b', 'b', 3),
          cluster_cookie = _G.cluster.cookie,
          http_port = 8084,
          advertise_port = 13304,
      })

      _G.cluster:start()
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      _G.cluster:server('test-storage-1'):stop()
      _G.server:start()

      return true
    `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: filtering', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.title().should('eq', 'cartridge-testing: Cluster');

    ////////////////////////////////////////////////////////////////////
    cy.log('Dashboard filtering');
    ////////////////////////////////////////////////////////////////////
    cy.contains('Replicasets');

    // Healthy
    cy.get('input[placeholder="Filter by uri, uuid, role, alias "]').prev('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Healthy)').click({ force: true });
    cy.get('.meta-test__Filter input').should('have.value', 'status:healthy');
    cy.get('.ServerLabelsHighlightingArea').contains('test-storage-1').should('not.exist');

    // Unhealthy
    cy.get('input[placeholder="Filter by uri, uuid, role, alias "]').prev('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Unhealthy)').click({ force: true });
    cy.get('.meta-test__Filter input').should('have.value', 'status:unhealthy');
    cy.get('.ServerLabelsHighlightingArea').contains('test-storage-1');

    // Role
    cy.get('input[placeholder="Filter by uri, uuid, role, alias "]').prev('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown').find('*:contains(vshard-storage)').click({ force: true });
    cy.get('.meta-test__Filter input').should('have.value', 'role:vshard-storage');
    cy.get('.ServerLabelsHighlightingArea').contains('test-storage-1');
    cy.get('#root').contains('test-storage');
    cy.get('#root').contains('test-router').should('not.exist');

    // Clear filter
    cy.get('.meta-test__Filter svg').eq(1).click();

    // Search
    cy.get('input[placeholder="Filter by uri, uuid, role, alias "]').type('test-storage-1');
    cy.get('#root').contains('test-storage');
    cy.get('#root').contains('test-router').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Join server dialog filtering');
    ////////////////////////////////////////////////////////////////////
    cy.get('li').contains('spare').closest('li').find('button').contains('Configure').click();
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();

    // Healthy
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Healthy)').click({ force: true });
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input').should('have.value', 'status:healthy');
    cy.get('.meta-test__ConfigureServerModal').contains('test-storage').should('not.exist');

    // Unhealthy
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(Unhealthy)').click({ force: true });
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input').should('have.value', 'status:unhealthy');
    cy.get('.meta-test__ConfigureServerModal').contains('test-router').should('not.exist');

    // Role
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown *:contains(vshard-router)').click({ force: true });
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input').should('have.value', 'role:vshard-router');
    cy.get('.meta-test__ConfigureServerModal').contains('test-storage').should('not.exist');

    // Clear filter
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter svg').eq(1).click();

    // Search
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter').find('input').type('test-storage');
    cy.get('.meta-test__ConfigureServerModal').contains('test-storage');
    cy.get('.meta-test__ConfigureServerModal').contains('test-router').should('not.exist');

    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Cancel)').click();
  });
});
