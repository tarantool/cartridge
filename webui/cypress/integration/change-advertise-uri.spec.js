describe('Change advertise uri', () => {

  before(() => {
    cy.task('tarantool', {code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = 'test-cluster-cookie',
        env = {TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0},
        replicasets = {{
          alias = 'test-replicaset',
          roles = {},
          servers = {{http_port = 8080}},
        }}
      })

      _G.cluster:start()
      _G.cluster.main_server:stop()

      _G.cluster.main_server.env['TARANTOOL_ADVERTISE_URI'] = 'localhost:3312'
      _G.cluster.main_server.net_box_uri = 'localhost:3312'
      _G.cluster.main_server:start()
      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__ProbeServerBtn').should('exist');
    cy.get('.meta-test__AuthToggle').should('not.exist');
  });

  it.skip('Test', () => {
  });
});
