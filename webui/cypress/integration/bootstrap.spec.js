import { sizes } from '../support/commands.js';

describe('Replicaset configuration & Bootstrap Vshard', () => {
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
        }}
      })

      for _, server in ipairs(_G.cluster.servers) do
        server.env.TARANTOOL_INSTANCE_NAME = server.alias
        server.env.TARANTOOL_CONSOLE_SOCK =
          _G.cluster.datadir .. '/' .. server.alias .. '.control'
        server:start()
      end

      helpers.retrying({}, function()
        _G.cluster:server('dummy-1'):graphql({query = '{ servers { uri } }'})
      end)

      return _G.cluster:server('dummy-1').env.TARANTOOL_CONSOLE_SOCK
    `,
    }).then((resp) => {
      const sock = resp[0];
      expect(sock).to.be.a('string');
      cy.task('tarantool', {
        host: 'unix/',
        port: sock,
        code: `
        package.loaded.mymodule.implies_router = true
        package.loaded.mymodule.implies_storage = true
        return true
      `,
      }).should('deep.eq', [true]);
    });
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function checksForErrorDetails() {
    cy.contains('Invalid cluster topology config');
    cy.get('div').contains('stack traceback:');

    cy.get('button[type="button"]:contains(Copy details)').trigger('mouseover');
    cy.get('div').contains('Copy to clipboard');

    cy.get('button[type="button"]:contains(Copy details)').click();
    cy.get('div').contains('Copied');
    cy.get('div').contains('Copy to clipboard');

    cy.get('button[type="button"]').contains('Close').click();
    cy.contains('Invalid cluster topology config').should('not.exist');
  }

  it('Test: bootstrap', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.title().should('eq', 'dummy-1: Cluster');
    cy.testScreenshots('3UnconfiguredServers');
    cy.get('.meta-test__UnconfiguredServerList').contains(':13301').closest('li').find('.meta-test__youAreHereIcon');
    cy.get('.meta-tarantool-app').contains('Total unconfigured instances3');
    cy.get('.meta-test__UnconfiguredServerList li').should('have.length', 3);

    ////////////////////////////////////////////////////////////////////
    cy.log('Bootstrap vshard on unconfigured cluster');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__BootstrapButton').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Select all roles');
    ////////////////////////////////////////////////////////////////////

    // Open create replicaset dialog
    sizes.forEach((size) => {
      cy.setResolution(size);
      // eslint-disable-next-line cypress/no-unnecessary-waiting
      cy.wait(1000);
      cy.get('.meta-test__configureBtn').first().click();
      cy.focused().blur();
      cy.get('.meta-test__ConfigureServerModal div').eq(1).matchImageSnapshot(`ConfigurationServer.${size}`);
      cy.get('button').contains('Cancel').click();
    });

    cy.get('.meta-test__configureBtn').first().click();
    cy.get('form input[name="alias"]').should('be.focused').type('for-default-group-tests');
    cy.get('form input[value="default"]').should('be.disabled');
    cy.get('form input[name="weight"]').should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // Check Select all roles
    cy.get('button[type="button"]').contains('Select all').click();
    cy.get('form input[value="default"]').should('be.checked');
    cy.get('form input[name="weight"]').should('be.enabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // Check Deselect all roles
    cy.get('button[type="button"]').contains('Deselect all').click();
    cy.get('form input[value="default"]').should('be.disabled');
    cy.get('form input[name="weight"]').should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // close dialog without saving
    cy.get('button[type="button"]:contains(Cancel)').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Select myrole');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__configureBtn:visible').should('have.length', 1).click();
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').should('not.exist');

    cy.get('.meta-test__ConfigureServerModal')
      .contains('dummy-1')
      .closest('li')
      .find('.meta-test__youAreHereIcon')
      .should('exist');

    // Open create replicaset dialog
    cy.get('form input[name="weight"]').should('be.disabled');
    cy.get('form input[value="default"]').should('be.disabled');
    cy.get('form input[value="vshard-router"]').should('not.be.checked');
    cy.get('form input[value="vshard-storage"]').should('not.be.checked');

    // Check myrole
    cy.get('form input[value="myrole"]').check({ force: true }).should('be.checked');
    cy.get('form input[value="myrole-dependency"]').should('be.disabled').should('be.checked');
    cy.get('form input[name="weight"]').should('be.enabled');
    cy.get('form input[value="default"]').should('be.checked');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('#root').contains('unnamed');

    cy.get('.meta-test__BootstrapButton').click();
    cy.get('.meta-test__BootstrapPanel__vshard-router_enabled').should('exist');
    cy.get('.meta-test__BootstrapPanel__vshard-storage_enabled').should('exist');

    // Check health state
    cy.get('.meta-tarantool-app').contains('Total unconfigured instances2');
    cy.get('.meta-test__UnconfiguredServerList li').should('have.length', 2);

    // cy.get('.meta-tarantool-app').contains('Healthy 1');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');

    cy.get(
      'span:contains(GraphQL error) + ' + 'span:contains(No remotes with role "vshard-router" available) + button + svg'
    ).click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Configure vshard-router');
    ////////////////////////////////////////////////////////////////////

    // Disable myrole
    cy.get('#root').contains('unnamed').closest('li').find('[data-cy=meta-test__editBtn]').click();
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]').should('be.focused');

    cy.get('form input[value="myrole"]').uncheck({ force: true }).should('not.be.checked');
    cy.get('form input[value="myrole-dependency"]').should('be.enabled').should('not.be.checked');

    //Try to enter invalid alias
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]').type(' ');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');

    //Fix invalid alias
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]').type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');
    cy.get('form input[name="alias"]').type('test-router').should('have.value', 'test-router');

    cy.get('form input[value="vshard-router"]').check({ force: true }).should('be.checked');
    cy.get('form input[value="vshard-storage"]').should('not.be.checked');

    cy.get('form input[name="all_rw"]').check({ force: true });
    cy.get('form input[name="all_rw"]').should('be.checked');

    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('#root').contains('test-router');

    cy.get('.ServerLabelsHighlightingArea')
      .contains('dummy-1')
      .closest('.ServerLabelsHighlightingArea')
      .find('.meta-test__youAreHereIcon')
      .should('exist');

    //Check health state
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(0).contains('healthy');
    cy.get('.meta-test__ReplicasetServerList').contains('healthy');

    ////////////////////////////////////////////////////////////////////
    cy.log('Bootstrap vshard on semi-configured cluster');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('.meta-test__BootstrapPanel__vshard-router_enabled').should('exist');
    cy.get('.meta-test__BootstrapPanel__vshard-storage_disabled').should('exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Configure vshard-storage');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__configureBtn:visible').should('have.length', 2);
    cy.contains('dummy-2').closest('li').find('.meta-test__configureBtn').click();

    cy.get('form input[name="alias"]').type('test-storage').should('have.value', 'test-storage');
    cy.get('form input[value="vshard-storage"]').check({ force: true });
    cy.get('form input[value="default"]').should('be.enabled').should('be.checked');

    cy.get('form input[value="vshard-storage"]').uncheck({ force: true });
    cy.get('form input[value="default"]').should('be.disabled').should('not.be.checked');
    cy.get('form input[name="weight"]').should('be.disabled');

    cy.get('form input[value="vshard-storage"]').check({ force: true });

    // Try to enter invalid weight
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').type('q');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.disabled');

    // Fix invalid weight
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('{selectall}{backspace}')
      .type('1.35')
      .should('have.value', '1.35');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    cy.get('form input[value="myrole"]').should('not.be.checked');
    cy.get('form input[value="myrole-dependency"]').should('not.be.checked');
    cy.get('form input[value="vshard-router"]').should('not.be.checked');
    cy.get('form input[value="vshard-storage"]').should('be.checked');

    cy.get('form input[name="all_rw"]').check({ force: true }).should('be.checked');

    cy.get('.meta-test__CreateReplicaSetBtn').click();

    cy.get('#root').contains('test-storage');
    cy.get('.meta-test__ReplicasetList_allRw_enabled').should('have.length', 2);

    // Check health state
    cy.get('section').eq(0).contains('Total unconfigured instances1');
    cy.get('.meta-test__UnconfiguredServerList').should('have.length', 1);
    cy.get('[data-component=ReplicasetListHeader]').contains('Total replicasets2');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(1).contains('healthy');

    ////////////////////////////////////////////////////////////////////
    cy.log('Bootstrap vshard on fully-configured cluster');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__BootstrapPanel__vshard-router_enabled');
    cy.get('.meta-test__BootstrapPanel__vshard-storage_enabled');
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('span:contains(VShard bootstrap is OK. Please wait for list refresh...)').click();
    cy.get('.meta-test__BootstrapButton').should('not.exist');
    cy.get('.meta-test__BootstrapPanel').should('not.exist');

    //////////////////////////////////////////////////////////////////
    cy.log('Edit vshard-storage');
    ////////////////////////////////////////////////////////////////////
    cy.get('li').contains('test-storage').closest('li').find('[data-cy=meta-test__editBtn]').click();

    // Try to enter empty alias
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]').type(' ');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]').type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');

    cy.get('form input[name="alias"]').type('{selectall}edited-storage').should('have.value', 'edited-storage');
    cy.get('form input[name="all_rw"]').uncheck({ force: true }).should('not.be.checked');

    cy.get('form input[value="myrole"]').uncheck({ force: true }).should('not.be.checked');
    cy.get('form input[value="myrole-dependency"]').should('be.enabled').should('not.be.checked');
    cy.get('form input[value="vshard-storage"]').should('be.checked');
    cy.get('form input[value="default"]').should('be.checked').should('be.disabled');
    cy.get('form input[name="weight"]').should('be.enabled');

    // Try to enter invalid weight
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]').type('q');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]').type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');

    cy.get('.meta-test__EditReplicasetModal input[name="weight"]').type('1.35');

    cy.get('form input[value="vshard-storage"]').uncheck({ force: true });
    cy.get('form input[value="default"]').should('be.checked').should('be.disabled');
    cy.get('form input[name="weight"]').should('have.value', '1.35').should('be.disabled');

    cy.get('form input[value="vshard-storage"]').check({ force: true });

    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
    cy.get('span:contains(Successful) + span:contains(Edit is OK. Please wait for list refresh...) + svg').click();

    cy.get('#root')
      .contains('edited-storage')
      .closest('li')
      .find('.meta-test__ReplicasetList_allRw_enabled')
      .should('not.exist');

    //////////////////////////////////////////////////////////////////
    cy.log('Join existing replicaset');
    ////////////////////////////////////////////////////////////////////
    sizes.forEach((size) => {
      cy.setResolution(size);
      // eslint-disable-next-line cypress/no-unnecessary-waiting
      cy.wait(1000);
      cy.get('.meta-test__configureBtn').should('have.length', 1).click({ force: true });
      cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();
      // need to add mock to save the same items order
      // cy.focused().blur();
      // cy.get('.meta-test__ConfigureServerModal div').eq(1).matchImageSnapshot(`JoinReplicasets.${size}`);
      cy.get('button').contains('Cancel').click();
    });
    cy.get('.meta-test__configureBtn').should('have.length', 1).click({ force: true });
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();
    cy.get('form input[name="replicasetUuid"]').first().check({ force: true });
    cy.get('.meta-test__JoinReplicaSetBtn').click();
    cy.get('span:contains(Successful) + span:contains(Join is OK. Please wait for list refresh...) + svg').click();

    //Check health state
    cy.get('[data-component=ReplicasetListHeader]').contains('Total replicasets2');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(1).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(2).contains('healthy');

    //////////////////////////////////////////////////////////////////
    cy.log('Expel server');
    ////////////////////////////////////////////////////////////////////
    sizes.forEach((size) => {
      cy.setResolution(size);
      // eslint-disable-next-line cypress/no-unnecessary-waiting
      cy.wait(1000);
      cy.get('li')
        .contains('dummy-3')
        .closest('.ServerLabelsHighlightingArea')
        .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
        .click();
      cy.get('.meta-test__ReplicasetServerListItem__dropdown').matchImageSnapshot(`ReplicaserServerDropdown.${size}`);
      cy.get('li')
        .contains('dummy-3')
        .closest('.ServerLabelsHighlightingArea')
        .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
        .click();
    });

    cy.get('li')
      .contains('dummy-3')
      .closest('.ServerLabelsHighlightingArea')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
      .click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Expel server').click({ force: true });
    cy.testElementScreenshots('ExpelServer', 'div.meta-test__ExpelServerModal');
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();

    cy.get('span:contains(Expel is OK. Please wait for list refresh...)').click();

    //////////////////////////////////////////////////////////////////
    cy.log('Show expel error and error details');
    ////////////////////////////////////////////////////////////////////
    cy.get('button.meta-test__LoginBtn').parent('div').parent('div').prev().click();
    cy.get('button:contains(Clear)').click();
    cy.get('.ServerLabelsHighlightingArea')
      .contains('dummy-1')
      .closest('.ServerLabelsHighlightingArea')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
      .click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('span:contains(Current instance "localhost:13301" can not be expelled)');
    cy.get('button[type="button"]:contains(Error details)').click();
    cy.get('span:contains(Current instance "localhost:13301" can not be expelled)').click();
    checksForErrorDetails();

    ////////////////////////////////////////////////////////////////////
    cy.log('Error details in notification list');
    ////////////////////////////////////////////////////////////////////
    cy.get('button.meta-test__LoginBtn').parent('div').parent('div').prev().click();
    cy.get('button[type="button"]:contains(Error details)').click();
    checksForErrorDetails();

    ////////////////////////////////////////////////////////////////////
    cy.log('Check Clear button in notification list');
    ////////////////////////////////////////////////////////////////////
    cy.get('button.meta-test__LoginBtn').parent('div').parent('div').prev().click();
    cy.get('button:contains(Clear)').click();
    cy.get('button.meta-test__LoginBtn').parent('div').parent('div').prev().click();
    cy.get('span').contains('No notifications');

    //Check health state
    cy.get('[data-component=ReplicasetListHeader]').contains('Total replicasets2');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('[data-cy=meta-test__replicaSetSection]').eq(1).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
  });
});
