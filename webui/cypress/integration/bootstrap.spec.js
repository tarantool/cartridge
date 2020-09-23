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
    cy.get('form input[name="alias"]').type('for-default-group-tests');
    cy.get('form input[value="default"]').should('be.disabled');
    cy.get('form input[name="weight"').should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // Check Select all roles
    cy.get('button[type="button"]').contains('Select all').click();
    cy.get('form input[value="default"]').should('be.checked');
    cy.get('form input[name="weight"').should('be.enabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // Check Deselect all roles
    cy.get('button[type="button"]').contains('Deselect all').click();
    cy.get('form input[value="default"]').should('be.disabled');
    cy.get('form input[name="weight"').should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // close dialog without saving
    cy.get('button[type="button"]:contains(Cancel)').click();
  });

  it('Configure vshard-router', () => {
    cy.get('.meta-test__configureBtn:visible').should('have.length', 1).click();
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').should('not.exist');

    cy.get('form').contains('dummy-1')
      .closest('li').find('.meta-test__youAreHereIcon').should('exist');
    cy.get('form input[name="alias"]').type('test-router').should('have.value', 'test-router');
    cy.get('form input[value="myrole"]').check({force: true}).should('be.checked');;
    cy.get('form input[value="myrole-dependency"]').should('be.disabled').should('be.checked');

    cy.get('form input[value="vshard-router"]').check({force: true}).should('be.checked');
    cy.get('form input[value="vshard-storage"]').should('not.be.checked');

    cy.get('form input[name="all_rw"]').check({ force: true });
    cy.get('form input[name="all_rw"]').should('be.checked');

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
    cy.get('.meta-test__configureBtn:visible').should('have.length', 2);
    cy.contains('dummy-2').closest('li').find('.meta-test__configureBtn').click();

    cy.get('form input[name="alias"]').type('test-storage').should('have.value', 'test-storage');

    cy.get('form input[value="vshard-storage"]').check({ force: true });
    cy.get('form input[value="default"]').should('be.enabled').should('be.checked');

    cy.get('form input[value="vshard-storage"]').uncheck({ force: true });
    cy.get('form input[value="default"]').should('be.disabled').should('not.be.checked');
    cy.get('form input[name="weight"]').should('be.disabled');

    cy.get('form input[value="vshard-storage"]').check({ force: true });

    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
    cy.get('form input[name="weight"]').type('1.35').should('have.value', '1.35');

    cy.get('form input[value="myrole"]').should('not.be.checked');
    cy.get('form input[value="myrole-dependency"]').should('not.be.checked');
    cy.get('form input[value="vshard-router"]').should('not.be.checked');
    cy.get('form input[value="vshard-storage"]').should('be.checked');

    cy.get('form input[name="all_rw"]').check({ force: true }).should('be.checked');

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

  it('Edit vshard-storage', () => {
    cy.get('li').contains('test-storage').closest('li').find('button').contains('Edit').click();

    cy.get('form input[name="alias"]').type('{selectall}edited-storage').should('have.value', 'edited-storage');
    cy.get('form input[name="all_rw"]').uncheck({ force: true }).should('not.be.checked');

    cy.get('form input[value="myrole"]').uncheck({ force: true }).should('not.be.checked');
    cy.get('form input[value="myrole-dependency"]').should('be.enabled').should('not.be.checked');
    cy.get('form input[value="vshard-storage"]').should('be.checked');
    cy.get('form input[value="default"]').should('be.checked').should('be.disabled');
    cy.get('form input[name="weight"]').should('be.enabled');

    cy.get('form input[value="vshard-storage"]').uncheck({ force: true });
    cy.get('form input[value="default"]').should('be.checked').should('be.disabled');
    cy.get('form input[name="weight"]').should('have.value', '1.35').should('be.disabled');

    cy.get('form input[value="vshard-storage"]').check({ force: true });

    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Successful) + span:contains(Edit is OK. Please wait for list refresh...)').click();

    cy.get('#root').contains('edited-storage').closest('li')
      .find('.meta-test__ReplicasetList_allRw_enabled').should('not.exist');
  });

  it('Join existing replicaset', () => {
    cy.get('.meta-test__configureBtn').should('have.length', 1).click({ force: true });
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();
    cy.get('form input[name="replicasetUuid"]').first().check({ force: true });
    cy.get('.meta-test__JoinReplicaSetBtn').click();
    cy.get('span:contains(Successful) + span:contains(Join is OK. Please wait for list refresh...)').click();
  });

  it('Expel server', () => {
    cy.get('li').contains('dummy-3').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();

    cy.get('span:contains(Expel is OK. Please wait for list refresh...)').click();
  });

  it('Show expel error', () => {
    cy.get('li').contains('dummy-1').closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();

    cy.get('span:contains(Current instance "localhost:13301" can not be expelled)').click();
  });
});
