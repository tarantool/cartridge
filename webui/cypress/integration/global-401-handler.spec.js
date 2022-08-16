describe('Global 401 handler', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = 'test-cluster-cookie',
        replicasets = {{
          roles = {},
          alias = 'dummy',
          servers = {{http_port = 8080}}
        }}
      })

      _G.cluster:server('dummy-1').env.TARANTOOL_CONSOLE_SOCK =
        _G.cluster.datadir .. '/control.sock'

      _G.cluster:start()
      return _G.cluster.datadir
    `,
    }).then((resp) => {
      const workdir = resp[0];
      expect(workdir).to.be.a('string');
      cy.task('tarantool', {
        host: 'unix/',
        port: workdir + '/control.sock',
        code: `
          local fun = require('fun')
          local cartridge = require('cartridge')
          local httpd = cartridge.service_get('httpd')
          local route = fun.iter(httpd.routes)
            :filter(function(r) return r.path == '/admin/api' end)
            :head()

          local _sub = route.sub
          route.sub = function(req)
              cartridge.http_authorize_request(req)
              if cartridge.http_get_username() ~= 'admin' then
                  return {status = 401}
              end
              return _sub(req)
          end

          return true
        `,
      }).should('deep.eq', [true]);
    });
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: global-401-handler', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');

    ////////////////////////////////////////////////////////////////////
    cy.log('Test 401 error');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginFormSplash').contains('Authorization');
    cy.get('.meta-test__LoginFormSplash').contains('Please, input your credentials');
    cy.get('input[name="username"]').type('admin');
    cy.get('input[name="password"]').type('test-cluster-cookie{enter}');

    cy.get('.meta-test__LogoutBtn').contains('Cartridge Administrator').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();

    cy.get('.meta-test__LoginFormSplash').should('be.visible');
  });
});
