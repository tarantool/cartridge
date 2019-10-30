//Test check validate in:
//1. Create replicaset dialog
//2. Probe server dialog
//3. Edit replicaset dialog
//4. Add user dialog

describe('Replicaset configuration & Bootstrap Vshard', () => {

  it('1. Create replicaset dialog', () => {
    cy.visit(Cypress.config('baseUrl'));

    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type(' ');
    cy.get('.meta-test__ConfigureServerModal').contains('Alias must contain only alphanumerics');

    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__ConfigureServerModal').contains('Alias must contain only alphanumerics').should('not.exist');
    
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('for-validate-tests');
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click();

    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('q');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number');

    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number').should('not.exist');

    cy.get('.meta-test__CreateReplicaSetBtn').click();
  })

  it('2. Probe server dialog',() => {
    cy.get('.meta-test__ProbeServerBtn').click();
    cy.get('.ProbeServerModal input[name="uri"]')
      .type(' ');
    cy.get('.meta-test__ProbeServerSubmitBtn').click();//component:ProbeServerModal
    cy.get('.ProbeServerModal').contains('Probe " " failed: parse error');
    cy.get('.ProbeServerModal input[name="uri"]')
      .type('local');
    cy.get('.meta-test__ProbeServerSubmitBtn').click();//component:ProbeServerModal
    cy.get('.ProbeServerModal').contains('Probe " " failed: parse error').should('not.exist');
  })

  it('3. Edit replicaset dialog',() => {
    cy.get('li').contains('for-validate-tests').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type(' ');
    cy.get('.meta-test__EditReplicasetModal').contains('Alias must contain only alphanumerics');

    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Alias must contain only alphanumerics').should('not.exist');
    
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]')
      .type('q');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number');

    cy.get('.meta-test__EditReplicasetModal input[name="weight"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();//component:EditReplicasetForm
  })

it('4. Add user dialog',() => {
    cy.get('a[href="/admin/cluster/users"]').click({ force: true });
    cy.get('.meta-test__addUserBtn').click({ force: true }); //webui/src/pages/Users/index.js
    cy.get('.meta-test__UserAddForm input[name="email"]')
      .type('not_valid');
    cy.get('.meta-test__UserAddForm input[name="username"]').focus();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email');

    cy.get('.meta-test__UserAddForm input[name="email"]')
      .type('qq@qq.qq');
    cy.get('.meta-test__UserAddForm input[name="username"]').focus();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email').should('not.exist');
  })
  
});