describe('Vshardless', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()
      
      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_vshardless'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        replicasets = {{
          alias = 'test-replicaset',
          roles = {},
          servers = {{http_port = 8080}},
        }}
      })

      for _, server in ipairs(_G.cluster.servers) do
        server.env.TARANTOOL_INSTANCE_NAME = server.alias
        server.env.TARANTOOL_CONSOLE_SOCK =
          _G.cluster.datadir .. '/' .. server.alias .. '.control'
        server:start()
      end

      helpers.retrying({}, function()
        _G.cluster:server('test-replicaset-1'):graphql({query = '{}'})
      end)

      return _G.cluster:server('test-replicaset-1').env.TARANTOOL_CONSOLE_SOCK
    `
    }).then((resp) => {
      const sock = resp[0];
      expect(sock).to.be.a('string');
      cy.task('tarantool', {
        host: 'unix/', port: sock, code: `
        package.loaded.mymodule.implies_router = true
        package.loaded.mymodule.implies_storage = true
        return true
      `}).should('deep.eq', [true]);
    });
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__ProbeServerBtn').should('exist');
  });

  it('Checks for vshardless', () => {
    cy.get('.meta-test__configureBtn').first().click();
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
    cy.get('form input[value="vshard-storage"]').should('not.exist');
    cy.get('form input[name="weight"]').should('be.disabled');
    cy.get('form input[value="default"]').should('not.exist');
    cy.get('.meta-test__ConfigureServerModal h2:contains(Configure server)').next().click();
  })
})
