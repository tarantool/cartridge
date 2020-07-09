const testPort = `:13311`;

describe('Replicaset configuration & Bootstrap Vshard', () => {

  before(function() {
    cy.visit(Cypress.config('baseUrl')+"/admin/cluster/dashboard");
  });

  it('Tab title on Cluster page', () => {
    cy.title().should('eq', 'server1: Cluster')
  })

  it('You are here marker in unconfigured server list', () => {
    cy.get('.meta-test__UnconfiguredServerList').contains(testPort).closest('li')
    .find('.meta-test__youAreHereIcon');
  });

  it('You are here marker in selected servers list', () => {
    cy.get('.meta-test__UnconfiguredServerList').contains(testPort).closest('li').find('.meta-test__configureBtn').click();
    cy.get('.meta-test__ConfigureServerModal').contains(testPort).closest('li').find('.meta-test__youAreHereIcon');
    cy.get('button[type="button"]').contains('Cancel').click();
  });

  it('Click Bootstrap Vshard: without vshard-router, without vshard-storage', () => {
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('.meta-test__BootStrapPanel__vshard-router_disabled');//component: BootstrapPanel
    cy.get('.meta-test__BootStrapPanel__vshard-storage_disabled');//component: BootstrapPanel
  })

  it('Creates replicaset with vshard-router and myrole roles', () => {
    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('router1-do-not-use-me')
      .should('have.value', 'router1-do-not-use-me');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-router"]').check({ force: true });

    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole-dependency"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-router"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').should('not.be.checked');

    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="all_rw"]').should('be.checked');

    cy.get('.meta-test__CreateReplicaSetBtn').click();//component: CreateReplicasetForm

    cy.get('#root').contains('router1-do-not-use-me');
  })

  it('Click Bootstrap Vshard: with vshard-router, without vshard-storage', () => {
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('.meta-test__BootStrapPanel__vshard-router_enabled');
    cy.get('.meta-test__BootStrapPanel__vshard-storage_disabled');
  })

  it('Create replicaset with vshard-storage role', () => {
    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('storage1-do-not-use-me')
      .should('have.value', 'storage1-do-not-use-me');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').check({ force: true });
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').check({ force: true });
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

    cy.get('#root').contains('storage1-do-not-use-me');
    cy.get('.meta-test__ReplicasetList_allRw_enabled').should('have.length', 2);
  })

  it('Success Bootstrap Vshard', () => {
    cy.get('.meta-test__BootStrapPanel__vshard-router_enabled');
    cy.get('.meta-test__BootStrapPanel__vshard-storage_enabled');
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('span:contains(VShard bootstrap is OK. Please wait for list refresh...)').click();
    cy.get('.meta-test__BootstrapButton').should('not.exist');
  })

  it('You are here marker in replicaset server list', () => {
    cy.get('.ServerLabelsHighlightingArea').contains(testPort).closest('li')
    .find('.meta-test__youAreHereIcon');
  });

});
