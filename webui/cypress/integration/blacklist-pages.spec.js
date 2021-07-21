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
          TARANTOOL_WEBUI_BLACKLIST = '/cluster/configuration:/test/repair/jobs',
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
    `
    }).should('deep.eq', [true]);
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
    cy.request({ url: '/', failOnStatusCode: false }).its('status').should('equal', 404);
    cy.request({ url: '/abc', failOnStatusCode: false }).its('status').should('equal', 404);
  });

  it('Test:hide-menu-subitems', () => {
    cy.visit('/abc/admin/cluster/users');
    cy.window()
      .then(win => {
        const projectName = 'test';
        win.tarantool_enterprise_core.register(projectName, [
          {
            label: 'Repair Queues',
            path: `/${projectName}/repair`,
            expanded: true,
            items: [
              {
                label: 'Input',
                path: `/${projectName}/repair/input`
              },
              {
                label: 'Output',
                path: `/${projectName}/repair/output`
              },      {
                label: 'Jobs',
                path: `/${projectName}/repair/jobs`
              }
            ]
          }
        ], null, 'react');
        return Promise.resolve();
      })
      .then(() => {
        cy.get('a[href="/abc/admin/test/repair"]').should('exist').click();
        cy.get('a[href="/test/repair/input"]').should('exist');
        cy.get('a[href="/test/repair/output"]').should('exist');
        cy.get('a[href="/test/repair/jobs"]').should('not.exist');
      });
  });
});
