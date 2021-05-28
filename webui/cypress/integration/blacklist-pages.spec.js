describe('Blacklist pages', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        env = {
          TARANTOOL_WEBUI_PREFIX = 'abc/',
          TARANTOOL_WEBUI_BLACKLIST = '/cluster/configuration',
          TARANTOOL_WEBUI_ENFORCE_ROOT_REDIRECT = 'false',
        },
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
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: blacklist-pages', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Blacklisted pages are not listed in menu');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/abc/admin/cluster/dashboard');
    cy.contains('Not loaded').should('not.exist');
    cy.contains('test-replicaset');
    cy.get('a[href="/abc/admin/cluster/dashboard"]').should('exist');
    cy.get('a[href="/abc/admin/cluster/configuration"]').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Blacklisted pages cant be visited');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/abc/admin/cluster/configuration');
    cy.contains('Not loaded').should('exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Redirects are disabled');
    ////////////////////////////////////////////////////////////////////
    cy.request({url: '/', failOnStatusCode: false}).its('status').should('equal', 404);
    cy.request({url: '/abc', failOnStatusCode: false}).its('status').should('equal', 404);
  });
});
