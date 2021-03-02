describe('Server details', () => {

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
        _G.cluster.main_server.net_box:call(
          'package.loaded.cartridge.failover_set_params',
          {{failover_timeout = 0}}
        )
        return true
      `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');
  });

  it('All servers alive', () => {
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
  });

  it('Cluster Suggestions Panel', () => {
    cy.task('tarantool', { code: `_G.cluster:server('dummy-2').process:kill('KILL')` });
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    cy.get('.meta-test__ClusterSuggestionsPanel h5').contains('Disable instances');
    cy.get('.meta-test__ClusterSuggestionsPanel span').contains('Some instances are malfunctioning' + 
      ' and impede editing clusterwide configuration.' + 
      ' Disable them temporarily if you want to operate topology.');
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').should('be.enabled');
  });

  it('Expell dead server', () => {
    cy.get('li').contains('dummy-2').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('span:contains(Expel is OK. Please wait for list refresh...)').click();
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    cy.get('li:contains(dummy-2)').should('not.exist');
    cy.task('tarantool', { code: `_G.cluster:server('dummy-2'):start()` });
  });

  it('Review Cluster Suggestions Panel', () => {
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should('have.css', 'background-color', 'rgb(255, 255, 255)');
    
    cy.task('tarantool', { code: `_G.cluster:server('dummy-3').process:kill('KILL')` });
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();

    cy.get('.meta-test__DisableServersSuggestionModal h2').contains('Disable instances');
    cy.get('.meta-test__DisableServersSuggestionModal p').contains('Some instances are malfunctioning' + 
      ' and impede editing clusterwide configuration.' + 
      ' Disable them temporarily if you want to operate topology.');
    cy.get('.meta-test__DisableServersSuggestionModal li').contains('localhost:13303 (dummy-3)');
    cy.get('.meta-test__DisableServersSuggestionModal button').contains('Disable').click();
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');

    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should('have.css', 'background-color', 'rgb(250, 250, 250)');
  });

  it('Enable server menu', () => {
    // try to enable dead server:
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Enable server').click();
    cy.get('span:contains(Disabled state setting error) +' + 
      'span:contains(NetboxConnectError: "localhost:13303": Connection refused)').click();
    
    //VShard bootstrap:
    cy.get('li:contains(dummy)').find('button').contains('Edit').click();
    cy.get('button[type="button"]').contains('Select all').click();
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Successful) + span:contains(Edit is OK. Please wait for list refresh...)').click();
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('span:contains(VShard bootstrap is OK. Please wait for list refresh...)').click();

    // enable healthy server:
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should('have.css', 'background-color', 'rgb(250, 250, 250)');
    cy.task('tarantool', { code: `_G.cluster:server('dummy-3'):start()` });
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Enable server').click();
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should('have.css', 'background-color', 'rgb(255, 255, 255)');
  });
  
  it('Disable server menu', () => {
    //disable healthy server:
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Disable server').click();
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should('have.css', 'background-color', 'rgb(250, 250, 250)');

    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Enable server').click();

    //disable dead server:
    cy.task('tarantool', { code: `_G.cluster:server('dummy-3').process:kill('KILL')` });
    cy.reload();
    cy.get('.meta-test__ClusterSuggestionsPanel').should('exist');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Disable server').click();
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should('have.css', 'background-color', 'rgb(250, 250, 250)');

    cy.task('tarantool', { code: `_G.cluster:server('dummy-3'):start()` });
  });
});
