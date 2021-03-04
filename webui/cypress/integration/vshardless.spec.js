describe('Vshardless', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_vshardless'),
        use_vshard = false,
        cookie = helpers.random_cookie(),
        replicasets = {{
          alias = 'test-replicaset',
          roles = {},
          servers = {{http_port = 8080}},
        }}
      })

      for _, server in ipairs(_G.cluster.servers) do
        server:start()
      end

      helpers.retrying({}, function()
        _G.cluster:server('test-replicaset-1'):graphql({query = '{ servers { uri } }'})
      end)

      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: vshardless', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Vshardless: Configure Server Modal');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__ProbeServerBtn').should('exist');
    cy.get('.meta-test__BootstrapButton').should('not.exist');

    cy.get('.meta-test__configureBtn').first().click();
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
    cy.get('form input[name="alias"]').type('test-replicaset');
    cy.get('form input[value="vshard-storage"]').should('not.exist');
    cy.get('form input[name="weight"]').should('be.disabled');
    cy.get('form input[value="default"]').should('not.exist');
    //checks all available roles
    cy.get('button[type="button"]').contains('Select all').click();
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('.meta-test__configureBtn').should('not.exist');
    cy.get('li').contains('failover-coordinator | myrole')

    ////////////////////////////////////////////////////////////////////
    cy.log('Vshardless: Edit Replicaset Modal');
    ////////////////////////////////////////////////////////////////////
    cy.get('li').contains('failover-coordinator | myrole').closest('li')
      .find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');
    cy.get('form input[value="vshard-storage"]').should('not.exist');
    cy.get('form input[name="weight"]').should('be.disabled');
    cy.get('form input[value="default"]').should('not.exist');
    //checks all available roles
    cy.get('button[type="button"]').contains('Deselect all').click();
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Successful) + span:contains(Edit is OK. Please wait for list refresh...)').click();
    cy.get('li').should('not.contain', 'failover-coordinator | myrole');
  });
});
