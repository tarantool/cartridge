describe('Default group tests', () => {

  before(() => {
    cy.task('tarantool', {code: `
      cleanup()
      _G.server = helpers.Server:new({
        alias = 'spare',
        workdir = fio.tempdir(),
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('с'),
        http_port = 8080,
        advertise_port = 13300,
        cluster_cookie = helpers.random_cookie(),
      })
      _G.server:start()
      helpers.retrying({timeout = 5}, function()
        _G.server:graphql({query = '{}'})
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
  });

  // it('1. Open Create replicaset dialog', () => {
  //   cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
  //   cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
  //     .type('for-default-group-tests');

  //   vshardGroup().should('be.disabled');
  //   replicaSetWeight().should('be.disabled');
  //   cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  // })

  // it('2. Check Select all roles', () => {
  //   cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click();
  //   cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.checked');
  //   cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.enabled');
  //   cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  // })

  // it('3. Check Deselect all roles', () => {
  //   cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Deselect all').click();
  //   cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.disabled');
  //   cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.disabled');
  //   cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  // })


  it('4. Check role vshard-storage', () => {
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').check();
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.enabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  })

  it('5. Create replicaset', () => {
    cy.get('.meta-test__CreateReplicaSetBtn').click();
    cy.get('#root').contains('for-default-group-tests');
  })

  it('6. Open Edit replicaset dialog', () => {
    cy.get('li').contains('for-default-group-tests').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="vshard_group"][value="default"]').should('be.disabled');
    cy.get('.meta-test__EditReplicasetModal input[name="vshard_group"][value="default"]').should('be.checked');
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]').should('be.enabled');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');
  })

  it('7. Try to change radiobutton Default in saved replicaset', () => {
    cy.get('.meta-test__EditReplicasetModal button[type="button"]').contains('Select all').click();
    cy.get('.meta-test__EditReplicasetModal input[name="vshard_group"][value="default"]').should('be.disabled');
    cy.get('.meta-test__EditReplicasetModal input[name="vshard_group"][value="default"]').should('be.checked');
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]').should('be.enabled');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');
    cy.get('.meta-test__EditReplicasetModal button[type="button"]').contains('Deselect all').click();
    cy.get('.meta-test__EditReplicasetModal input[name="vshard_group"][value="default"]').should('be.disabled');
    cy.get('.meta-test__EditReplicasetModal input[name="vshard_group"][value="default"]').should('be.checked');
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]').should('be.disabled');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');
  })
});
