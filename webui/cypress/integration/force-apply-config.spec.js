describe('Disable server', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()

        _G.cluster = helpers.Cluster:new({
          datadir = fio.tempdir(),
          server_command = helpers.entrypoint('srv_basic'),
          use_vshard = false,
          cookie = helpers.random_cookie(),
          replicasets = {{
            uuid = helpers.uuid('a'),
            alias = 'dummy',
            roles = {},
            servers = {{http_port = 8080}, {}, {}},
          }},
        })

        _G.cluster:start()
        helpers.run_remotely(_G.cluster.main_server, function()
          local confapplier = require('cartridge.confapplier')
          confapplier.set_state('ConfiguringRoles')
          confapplier.set_state('OperationError',
            require('errors').new('ArtificialError', 'the cake is a lie')
          )
        end)
        return true
      `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: disable-server', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('#root').contains('OperationError');
  });
});
