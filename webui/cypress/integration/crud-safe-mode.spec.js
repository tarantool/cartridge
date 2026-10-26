describe('CRUD safe mode badges', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()

        _G.cluster = helpers.Cluster:new({
          datadir = fio.tempdir(),
          server_command = helpers.entrypoint('srv_basic'),
          use_vshard = true,
          cookie = helpers.random_cookie(),
          replicasets = {{
            alias = 'router',
            roles = {'vshard-router'},
            servers = {{http_port = 8080}},
          }, {
            alias = 'storage',
            roles = {'vshard-storage'},
            servers = 2,
          }},
        })
        _G.cluster:start()
        return true
      `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  // Mimics the storage API which crud.init_storage() exports.
  function setCrudSafeMode(alias, enabled) {
    cy.task('tarantool', {
      code: `
        _G.cluster:server('${alias}'):exec(function(enabled)
          rawset(_G, '_crud', {
            rebalance_safe_mode_status = function() return enabled end,
          })
        end, {${enabled}})
        return true
      `,
    }).should('deep.eq', [true]);
  }

  function serverRow(alias) {
    return cy.contains(alias).closest('[data-component=ReplicasetServerListItem]');
  }

  function replicasetHeader(alias) {
    return cy.contains('[data-cy=meta-test__replicaSetSection]', alias);
  }

  it('Test: no badges without crud', () => {
    cy.visit('/admin/cluster/dashboard');
    serverRow('storage-1').contains('storage-1');
    cy.get('.meta-test__crudSafeMode').should('not.exist');
  });

  it('Test: safe mode on some instances', () => {
    setCrudSafeMode('storage-1', true);
    setCrudSafeMode('storage-2', false);
    cy.visit('/admin/cluster/dashboard');

    serverRow('storage-1').find('.meta-test__crudSafeMode').should('exist');
    serverRow('storage-2').find('.meta-test__crudSafeMode').should('not.exist');
    serverRow('router-1').find('.meta-test__crudSafeMode').should('not.exist');
    replicasetHeader('storage').find('.meta-test__crudSafeMode').should('have.text', 'safe mode 1/2');
    replicasetHeader('router').find('.meta-test__crudSafeMode').should('not.exist');
  });

  it('Test: safe mode on all instances', () => {
    setCrudSafeMode('storage-2', true);
    cy.visit('/admin/cluster/dashboard');

    serverRow('storage-2').find('.meta-test__crudSafeMode').should('exist');
    replicasetHeader('storage').find('.meta-test__crudSafeMode').should('have.text', 'safe mode');
  });
});
