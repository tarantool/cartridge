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
    cy.get('.meta-test__ServerDetailsModal button').contains('Issues 0').click();

    cy.get('.meta-test__ServerDetailsModal').closest('div').find('.meta-test__youAreHereIcon');

    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('div').contains('You have no any zone,');
    cy.get('div').contains('please add one.')
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="uri"]').type('Narnia');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.ZoneAddModal').should('not.exist');
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Narnia)');
    cy.get('button:contains(Close)').click();
    cy.get('.meta-test__ServerDetailsModal').should('not.exist');
    
    cy.get('li').contains('dummy-1').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *')
      .contains('Server details').click();
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Narnia)').click({force: true});
    cy.get('div').contains('You have no any zone,').should('not.exist');
    cy.get('button:contains(Add new zone)').should('be.enabled');

    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
  });

  it('Dead server', () => {
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', {failOnNonZeroExit: false});
    cy.reload();
    cy.get('.meta-test__LoginBtn');
    cy.get('.ServerLabelsHighlightingArea').contains('dummy-2')
      .closest('li').should('contain', 'Server status is "dead"');

    cy.get('li').contains('dummy-2').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *')
      .contains('Server details').click();

    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('div').contains('You have no any zone,').should('not.exist');
    cy.get('div').contains('Narnia');
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="uri"]').type('Moscow');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.ZoneAddModal_error').find('span:contains(Timeout exceeded)');
    cy.get('h2:contains(Add name of zone)').next().click();
    cy.get('.ZoneAddModal').should('not.exist');
    
    cy.get('.meta-test__ServerDetailsModal').contains('Server status is "dead"');
    cy.get('.meta-test__ServerDetailsModal').contains('instance_uuid').should('not.exist');
    
    cy.get('.meta-test__ServerDetailsModal button').contains('Cartridge').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Replication').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Storage').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Network').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('General').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Issues 0');
    cy.get('button:contains(Close)').click();

    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', {failOnNonZeroExit: false});
    cy.reload();
    cy.get('.meta-test__LoginBtn');
    cy.get('.ServerLabelsHighlightingArea').contains(':13302').closest('li')
      .contains('healthy');
    cy.get('li').contains('dummy-2').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *')
      .contains('Server details').click();
      
    cy.get('.meta-test__ServerDetailsModal').contains('healthy');
    cy.get('.meta-test__ServerDetailsModal').contains('instance_uuid');

    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="uri"]').type('Rostov');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.ZoneAddModal_error').find('span:contains(Two-phase commit is locked)', {timeout:15000});
    cy.get('h2:contains(Add name of zone)').next().click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Issues 1').click();
    cy.get('.meta-test__ServerDetailsModal').find('p')
      .contains('Configuration is prepared and locked on localhost:13302 (dummy-2)');
    cy.get('button:contains(Close)').click();

    //check issues on Cluster page
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal')
      .contains("warning: Configuration is prepared and locked on localhost:13302 (dummy-2)");
    cy.get('button:contains(Close)').click();

    // cy.task('tarantool', {code: `
    //   return _G.cluster:server('dummy-2').instance_uuid
    // `}).then((resp) => {
    //   const uuid = resp[0];
    //   cy.get('.meta-test__ServerDetailsModal').contains(uuid);
    // });
  });
});
