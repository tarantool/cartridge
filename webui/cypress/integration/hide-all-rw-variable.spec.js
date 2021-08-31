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
          servers = {{http_port = 8080}},
        }}
      })

      local server = _G.cluster:server('dummy-1')
      server.env.TARANTOOL_CONSOLE_SOCK =
        _G.cluster.datadir .. '/' .. server.alias .. '.control'
      server:start()

      return true
    `
    }).should('deep.eq', [true]);
  });

  beforeEach(() => {
    cy.task('tarantool', {
      code: `
      local server = _G.cluster:server('dummy-1')
      return {
        sock = server.env.TARANTOOL_CONSOLE_SOCK,
        advertise_uri = server.advertise_uri,
        replicaset_uuid = server.replicaset_uuid,
      }
    `
    }).then(([ret]) => {
      expect(ret.sock).to.be.a('string');
      expect(ret.advertise_uri).to.be.a('string');
      expect(ret.replicaset_uuid).to.be.a('string');
      cy.wrap(ret).as('main_server');
    });
  })

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function hideAllRW(value) {
    cy.get('@main_server').then(srv => {
      cy.task('tarantool', {
        host: 'unix/', port: srv.sock, code: `
        local frontend = package.loaded['frontend-core']
        frontend.set_variable("cartridge_hide_all_rw", ${value})
        return true
      `
      }).should('deep.eq', [true]);
    })
  }

  it('Test CreateReplicasetForm', function () {
    ////////////////////////////////////////////////////////////////////
    cy.log('cartridge_hide_all_rw is unset');
    hideAllRW('nil');
    cy.visit(`/admin/cluster/dashboard?s=${this.main_server.advertise_uri}`);

    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('cartridge_hide_all_rw is true');
    hideAllRW('true')
    cy.reload()

    cy.get('.meta-test__ConfigureServerModal').contains('dummy-1');
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('cartridge_hide_all_rw is false');
    hideAllRW('false');
    cy.reload()

    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('exist');

  });

  it('Test: EditReplicasetForm', function () {
    cy.task('tarantool', {code: '_G.cluster:bootstrap()'});

    ////////////////////////////////////////////////////////////////////
    cy.log('cartridge_hide_all_rw is unset');
    hideAllRW('nil');
    cy.visit(`/admin/cluster/dashboard?r=${this.main_server.replicaset_uuid}`);

    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').should('exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('cartridge_hide_all_rw is true');
    hideAllRW('true')
    cy.reload()

    cy.get('.meta-test__EditReplicasetModal').contains('dummy');
    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('cartridge_hide_all_rw is false');
    hideAllRW('false');
    cy.reload()

    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').should('exist');
  });
});
