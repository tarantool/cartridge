describe('Test the cartridge_hide_all_rw frontend core variable', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        env = {},
        replicasets = {{
          uuid = helpers.uuid('a'),
          alias = 'dummy',
          roles = {},
          servers = {{http_port = 8080}, {}, {}},
        }}
      })

      for _, server in ipairs(_G.cluster.servers) do
        server.env.TARANTOOL_INSTANCE_NAME = server.alias
        server.env.TARANTOOL_CONSOLE_SOCK =
          _G.cluster.datadir .. '/' .. server.alias .. '.control'
        server:start()
      end

      return true
    `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: cartridge_hide_all_rw is unset', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    cy.visit('/admin/cluster/dashboard');
    cy.title().should('eq', 'dummy-1: Cluster');
    ////////////////////////////////////////////////////////////////////
    cy.log('Open configure server dialog');
    cy.get('.meta-test__UnconfiguredServerList .meta-test__configureBtn').first().click();
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').first().should('exist');

    cy.log('Create replica set');
    cy.get('.meta-test__ConfigureServerModal form input[name="alias"]')
      .should('be.focused')
      .type('replica-name');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('.meta-test__ConfigureServerModal').should('not.exist');
    cy.get('#root').contains('replica-name');
    ////////////////////////////////////////////////////////////////
    cy.log('Open edit replica set dialog');
    cy.get('[data-cy=meta-test__replicaSetSection] [data-cy="meta-test__editBtn"]').first().click();
    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').first().should('exist');
    cy.get('.meta-test__EditReplicasetModal h2~svg').first().click(); // click close icon
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
  });

  it('Test: cartridge_hide_all_rw is FALSE', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Setup cartridge_hide_all_rw=false');
    cy.task('tarantool', {
      code: `
      _G.cluster:server('dummy-1').env.TARANTOOL_CONSOLE_SOCK
    `
    }).then(([sock]) => {
      expect(sock).to.be.a('string');
      cy.task('tarantool', {
        host: 'unix/', port: sock, code: `
        local frontend = package.loaded['frontend-core']
        frontend.set_variable('cartridge_hide_all_rw', false)
        return true
      `
      }).should('deep.eq', [true]);
    });
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    cy.visit('/admin/cluster/dashboard');
    cy.title().should('eq', 'dummy-1: Cluster');
    ////////////////////////////////////////////////////////////////////
    cy.log('Open configure server dialog');
    cy.get('.meta-test__UnconfiguredServerList .meta-test__configureBtn').first().click();
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').first().should('exist');

    cy.log('Create replica set');
    cy.get('.meta-test__ConfigureServerModal form input[name="alias"]')
      .should('be.focused')
      .type('replica-name');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('#root').contains('replica-name');
    cy.get('.meta-test__ConfigureServerModal').should('not.exist');
    ////////////////////////////////////////////////////////////////
    cy.log('Open edit replica set dialog');
    cy.get('[data-cy=meta-test__replicaSetSection] [data-cy="meta-test__editBtn"]').first().click();
    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').first().should('exist');
    cy.get('.meta-test__EditReplicasetModal h2~svg').first().click(); // click close icon
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
  });

  it('Test: cartridge_hide_all_rw is TRUE', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Setup cartridge_hide_all_rw=true');
    cy.task('tarantool', {
      code: `
      _G.cluster:server('dummy-1').env.TARANTOOL_CONSOLE_SOCK
    `
    }).then(([sock]) => {
      expect(sock).to.be.a('string');
      cy.task('tarantool', {
        host: 'unix/', port: sock, code: `
        local frontend = package.loaded['frontend-core']
        frontend.set_variable('cartridge_hide_all_rw', true)
        return true
      `
      }).should('deep.eq', [true]);
    });
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    cy.visit('/admin/cluster/dashboard');
    cy.title().should('eq', 'dummy-1: Cluster');
    ////////////////////////////////////////////////////////////////////
    cy.log('Open configure server dialog');
    cy.get('.meta-test__UnconfiguredServerList .meta-test__configureBtn').first().click();
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('not.exist');

    cy.log('Create replica set');
    cy.get('.meta-test__ConfigureServerModal form input[name="alias"]')
      .should('be.focused')
      .type('replica-name');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('.meta-test__ConfigureServerModal').should('not.exist');
    cy.get('#root').contains('replica-name');
    ////////////////////////////////////////////////////////////////
    cy.log('Open edit replica set dialog');
    cy.get('[data-cy=meta-test__replicaSetSection] [data-cy="meta-test__editBtn"]').first().click();
    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').should('not.exist');
    cy.get('.meta-test__EditReplicasetModal h2~svg').first().click(); // click close icon
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
  });
});
