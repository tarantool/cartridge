describe('Server details', () => {

  before(() => {
    cy.task('tarantool', {code: `
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
          servers = {{http_port = 8080}, {}},
        }},
      })

      _G.cluster:start()
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard')
  });

  it('Alive server', () => {
    cy.get('li').contains('dummy-1').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *')
      .contains('Server details').click();

    cy.get('.meta-test__ServerDetailsModal button').contains('Cartridge').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Replication').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Storage').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Network').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('General').click();
    cy.get('.meta-test__ServerDetailsModal').closest('div').find('.meta-test__youAreHereIcon');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
  });

  it('Dead server', () => {
    cy.task('tarantool', {code: `_G.cluster:server('dummy-2'):stop()`});

    cy.get('.ServerLabelsHighlightingArea').contains('dummy-2')
      .closest('li').should('contain', 'Server status is "dead"');

    cy.get('li').contains('dummy-2').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *')
      .contains('Server details').click();

    cy.get('.meta-test__ServerDetailsModal').contains('Server status is "dead"');
    cy.get('.meta-test__ServerDetailsModal').contains('instance_uuid').should('not.exist');

    cy.get('.meta-test__ServerDetailsModal button').contains('Cartridge').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Replication').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Storage').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Network').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('General').click();

    cy.task('tarantool', {code: `_G.cluster:server('dummy-2'):start()`});

    cy.get('.meta-test__ServerDetailsModal').contains('healthy');
    cy.get('.meta-test__ServerDetailsModal').contains('instance_uuid');

    cy.task('tarantool', {code: `
      return _G.cluster:server('dummy-2').instance_uuid
    `}).then((resp) => {
      const uuid = resp[0];
      cy.get('.meta-test__ServerDetailsModal').contains(uuid);

    });

    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
    cy.get('.ServerLabelsHighlightingArea').contains(':13302').closest('li')
      .contains('healthy');
  });
});
