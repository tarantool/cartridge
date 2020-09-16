describe('Blacklist pages', () => {

  before(() => {
    cy.task('tarantool', {code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        env = {TARANTOOL_WEBUI_BLACKLIST = '/cluster/configuration'},
        replicasets = {{
          roles = {},
          alias = 'test-replicaset',
          servers = {{http_port = 8080}},
        }},
      })

      _G.cluster:start()
      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Blacklisted pages arent visible', () => {
    // Blacklisted pages aren't listed in menu
    cy.visit('/admin/cluster/dashboard')
    cy.contains('Not loaded').should('not.exist');
    cy.contains('test-replicaset');
    cy.get('a[href="/admin/cluster/dashboard"]').should('exist');
    cy.get('a[href="/admin/cluster/configuration"]').should('not.exist');
  });

  it('Blacklisted pages cant be visited', () => {
    // Blacklisted pages can't be visited
    cy.visit('/admin/cluster/configuration');
    cy.contains('Not loaded').should('exist');
  });
});
