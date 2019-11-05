//Steps:
//1. Click Bootstrap Vshard: without vshard-router role, without vshard-storage role:
//      Press the button Bootstrap Vshard
//2. Create replicaset with vshard-router and myrole roles
//      Press the button Configure
//      Fill the field 'name of replica set'
//      Check roles: vshard-router and myrole
//      Press the button 'Create replica set'
//3. Click Bootstrap Vshard: with vshard-router, without vshard-storage
//      Press the button Bootstrap Vshard
//4. Create replicaset with vshard-storage role
//      Press the button Configure
//      Fill the field 'name of replica set'
//      Check roles: vshard-storage
//      Check group: Group
//      Fill the field Weigth
//      Press the button 'Create replica set'
//5. Success Bootstrap Vshard
//      Press the button Bootstrap Vshard
//      Press Escape for close dialog
//      Press Enter in dialog

describe('Replicaset configuration & Bootstrap Vshard', () => {
  it('Click Bootstrap Vshard: without vshard-router, without vshard-storage', () => {
    cy.visit(Cypress.config('baseUrl'));
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
      .type('1')
      .should('have.value', '1');

    cy.get('cc input[name="roles"][value="myrole"]').should('not.be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="myrole-dependency"]').should('not.be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-router"]').should('not.be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').should('be.checked');

    cy.get('.meta-test__CreateReplicaSetBtn').click();

    cy.get('#root').contains('storage1-do-not-use-me');
  })

  it('Success Bootstrap Vshard', () => {
    cy.get('.meta-test__BootStrapPanel__vshard-router_enabled');
    cy.get('.meta-test__BootStrapPanel__vshard-storage_enabled');
    cy.get('.meta-test__BootstrapButton').click();
    cy.get('#root').contains('VShard bootstrap is OK. Please wait for list refresh...');//add to frontend-core classname for notification
    cy.get('.meta-test__BootstrapButton').should('not.exist');
  })

  it('press Escape for close dialog', () => {
    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
    cy.get('.meta-test__ConfigureServerModal').type('{esc}');
    cy.get('.meta-test__ConfigureServerModal').should('not.exist');
  })

  it('press Enter in dialog', () => {
    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]').type('{enter}');
    cy.get('#root').contains('unnamed');
  })

});