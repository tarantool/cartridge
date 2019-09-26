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

describe('Replicaset configuration & Bootstrap Vshard', () => {
  it('Click Bootstrap Vshard: without vshard-router, without vshard-storage', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.contains('Bootstrap vshard').click();
    cy.get('.BootStrapPanel__vshard-router_disabled');
    cy.get('.BootStrapPanel__vshard-storage_disabled');
  })
  
  it('Creates replicaset with vshard-router and myrole roles', () => {
    cy.get('.UnconfiguredServerList button[type="button"]').contains('Configure').click();
    cy.get('.ConfigureServerModal input[name="alias"]')
      .type('router1')
      .should('have.value', 'router1');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="myrole"]').check({ force: true });
    cy.get('.ConfigureServerModal input[type="checkbox"][value="vshard-router"]').check({ force: true });

    cy.get('.ConfigureServerModal input[type="checkbox"][value="myrole"]').should('be.checked');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="myrole-dependency"]').should('be.checked');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="vshard-router"]').should('be.checked');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="vshard-storage"]').should('not.be.checked');
    
    cy.get('.ConfigureServerModal button[type="submit"]').contains('Create replica set').click();

    cy.get('#root').contains('router1');
  })

  it('Click Bootstrap Vshard: with vshard-router, without vshard-storage', () => {
    cy.contains('Bootstrap vshard').click();
    cy.get('.BootStrapPanel__vshard-router_enabled');
    cy.get('.BootStrapPanel__vshard-storage_disabled');
  })

  it('Create replicaset with vshard-storage role', () => {
    cy.get('.UnconfiguredServerList button[type="button"]').contains('Configure').click();
    cy.get('.ConfigureServerModal input[name="alias"]')
      .type('storage1')
      .should('have.value', 'storage1');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="vshard-storage"]').check({ force: true });
    cy.get('.ConfigureServerModal input[type="radio"][value="default"]').check({ force: true });
    cy.get('.ConfigureServerModal input[name="weight"]')
      .type('1')
      .should('have.value', '1');

    cy.get('.ConfigureServerModal input[type="checkbox"][value="myrole"]').should('not.be.checked');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="myrole-dependency"]').should('not.be.checked');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="vshard-router"]').should('not.be.checked');
    cy.get('.ConfigureServerModal input[type="checkbox"][value="vshard-storage"]').should('be.checked');
    
    cy.get('.ConfigureServerModal button[type="submit"]').contains('Create replica set').click();

    cy.get('#root').contains('storage1');
  })

  it('Success Bootstrap Vshard', () => {
    cy.get('.BootStrapPanel__vshard-router_enabled');
    cy.get('.BootStrapPanel__vshard-storage_enabled');
    cy.contains('Bootstrap vshard').click();
    cy.get('#root').contains('VShard bootstrap is OK. Please wait for list refresh...');
    cy.contains('Bootstrap vshard').should('not.exist');  
  })
});