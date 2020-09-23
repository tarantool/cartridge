describe('Replicaset configuration & Bootstrap Vshard', () => {

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
          servers = {{http_port = 8080}, {}, {}},
        }}
      })

      for _, server in ipairs(_G.cluster.servers) do
        server.env.TARANTOOL_INSTANCE_NAME = server.alias
        server:start()
      end

      helpers.retrying({}, function()
        _G.cluster:server('dummy-1'):graphql({query = '{}'})
      end)
      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  function vshardGroup() {
    return cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]')
  }

  function replicaSetWeight() {
    return cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
  }

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard')
    cy.title().should('eq', 'dummy-1: Cluster')
    cy.get('.meta-test__UnconfiguredServerList').contains(':13301')
      .closest('li').find('.meta-test__youAreHereIcon');
  });

  it('Bootstrap vshard on unconfigured cluster', () => {
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('.meta-test__BootstrapPanel__vshard-router_disabled').should('exist');
    cy.get('.meta-test__BootstrapPanel__vshard-storage_disabled').should('exist');
    cy.get('.meta-test__BootstrapPanel use:first').click();
    cy.get('.meta-test__BootstrapPanel').should('not.exist');
  });

  it('Select all roles', () =>{
    // Open create replicaset dialog
    cy.get('.meta-test__configureBtn').first().click();
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]').type('for-default-group-tests');
    vshardGroup().should('be.disabled');
    replicaSetWeight().should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // Check Select all roles
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click();
    vshardGroup().should('be.checked');
    replicaSetWeight().should('be.enabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // Check Deselect all roles
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Deselect all').click();
    vshardGroup().should('be.disabled');
    replicaSetWeight().should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // close dialog without saving
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Cancel)').click();
  });

  it('Configure vshard-router', () => {
    cy.get('.meta-test__configureBtn').first().click();
    cy.get('.meta-test__ConfigureServerModal').contains('dummy-1')
      .closest('li').find('.meta-test__youAreHereIcon').should('exist');
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('test-router')
      .should('have.value', 'test-router');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-router"]').check({ force: true });

    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole-dependency"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-router"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').should('not.be.checked');

    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('be.checked');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('#root').contains('test-router');

    cy.get('.ServerLabelsHighlightingArea').contains('dummy-1')
      .closest('li').find('.meta-test__youAreHereIcon').should('exist');
  });

  it('Bootstrap vshard on semi-configured cluster', () => {
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('.meta-test__BootstrapPanel__vshard-router_enabled').should('exist');
    cy.get('.meta-test__BootstrapPanel__vshard-storage_disabled').should('exist');
  });

  it('Configure vshard-storage', () => {
    cy.get('.meta-test__configureBtn').first().click();
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('test-storage')
      .should('have.value', 'test-storage');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.enabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('1.35')
      .should('have.value', '1.35');

    cy.get('cc input[name="roles"][value="myrole"]').should('not.be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole-dependency"]').should('not.be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-router"]').should('not.be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').should('be.checked');

    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('be.checked');

    cy.get('.meta-test__CreateReplicaSetBtn').click();

    cy.get('#root').contains('test-storage');
    cy.get('.meta-test__ReplicasetList_allRw_enabled').should('have.length', 2);
  });

  it('Bootstrap vshard on fully-configured cluster', () => {
    cy.get('.meta-test__BootstrapPanel__vshard-router_enabled');
    cy.get('.meta-test__BootstrapPanel__vshard-storage_enabled');
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('span:contains(VShard bootstrap is OK. Please wait for list refresh...)').click();
    cy.get('.meta-test__BootstrapButton').should('not.exist');
    cy.get('.meta-test__BootstrapPanel').should('not.exist');
  });
});
