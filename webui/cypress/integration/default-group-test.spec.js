//Steps:
//1. Open Create replicaset dialog
//2. Check Select all roles
//3. Check Deselect all roles
//4. Check role vshard-storage
//5. Create replicaset
//6. Open Edit replicaset dialog
//7. Try to change radiobutton Default in saved replicaset

describe('Default group tests', () => {

  it('1. Open Create replicaset dialog', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('for-default-group-tests');
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.disabled');
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  })

  it('2. Check Select all roles', () => {
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click();
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.checked');
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.enabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  })

  it('3. Check Deselect all roles', () => {
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Deselect all').click();
    cy.get('.meta-test__ConfigureServerModal input[name="vshard_group"][value="default"]').should('be.disabled');
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').should('be.disabled');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');
  })


  it('4. Check role vshard-storage', () => {
    cy.get('.meta-test__ConfigureServerModal input[name="roles"][value="vshard-storage"]').check({ force: true });
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
