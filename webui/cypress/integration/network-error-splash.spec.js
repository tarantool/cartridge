describe('Network error panel', () => {

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
          TARANTOOL_WEBUI_PREFIX = 'jkl',
        },
        replicasets = {{
          alias = 'test-replicaset',
          roles = {},
          servers = {{http_port = 8080}},
        }}
      })

      _G.cluster:start()
      return true
    `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: network-error-splash', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Check presence');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/jkl');

    // It's fine yet
    cy.get('.meta-test__ProbeServerBtn');
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');

    // Now kill the server
    cy.task('tarantool', { code: `_G.cluster.main_server:stop()` });

    cy.get('.meta-test__NetworkErrorSplash').should('exist')
      .contains('Network connection problem or server disconnected');

    cy.get('a[href="/jkl/admin/cluster/users"]').click();
    cy.get('h1:contains(Users)');
    cy.get('#root').contains('Network problem').should('exist');
    cy.get('#root').contains('Failed to fetch').should('exist');
    cy.get('#root').contains('LOADING').should('not.exist');
    cy.get('.meta-test__NetworkErrorSplash').should('exist');

    cy.get('a[href="/jkl/admin/cluster/dashboard"]').click();
    cy.get('#root').contains('Network problem').should('exist');

    cy.get('a[href="/jkl/admin/cluster/configuration"]').click();
    cy.get('#root').contains('Configuration Management').should('exist');
    cy.get('.meta-test__NetworkErrorSplash').should('exist');

    cy.get('a[href="/jkl/admin/cluster/code"]').click();
    cy.get('#root').contains('Loading...').should('not.exist');
    cy.get('#root').contains('Error loading component').should('exist');
    cy.get('button:contains(Retry)').should('exist');
    cy.get('.meta-test__NetworkErrorSplash').should('exist');

    // Repair the server
    cy.task('tarantool', { code: `_G.cluster.main_server:start()` });
    cy.get('button:contains(Retry)').click();
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');
  });
});
