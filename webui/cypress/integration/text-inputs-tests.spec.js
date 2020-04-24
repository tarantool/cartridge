//Test check validate in:
//1. Create replicaset dialog
//2. Probe server dialog
//3. Edit replicaset dialog
//4. Add user dialog

describe('Replicaset configuration & Bootstrap Vshard', () => {

  it('1. Create replicaset dialog', () => {
    cy.visit(Cypress.config('baseUrl'));

    cy.get('.meta-test__configureBtn').first().click();//component: UnconfiguredServerList

    // I. Invalid alias
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type(' ');
    cy.get('.meta-test__ConfigureServerModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.disabled');

    // II. Fix alias
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__ConfigureServerModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -').should('not.exist');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    // III. Select all roles
    cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
      .type('test-replicaset');
    cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click();

    // IV. Invalid weight
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('q');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.disabled');

    // V. Fix weight
    cy.get('.meta-test__ConfigureServerModal input[name="weight"]')
      .type('{selectall}{backspace}').type('1.0');
    cy.get('.meta-test__ConfigureServerModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__CreateReplicaSetBtn').should('be.enabled');

    cy.get('.meta-test__ConfigureServerModal input[name="weight"]').type('{enter}');
    cy.get('.meta-test__ConfigureServerModal').should('not.exist');

  })

  it('2. Probe server dialog',() => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__ProbeServerBtn').click();

    // I. Invalid uri
    cy.get('.ProbeServerModal input[name="uri"]')
      .type(' ');
    cy.get('.meta-test__ProbeServerSubmitBtn').click();
    cy.get('.ProbeServerModal_error').contains('Probe " " failed: parse error');

    // II. Fix uri
    cy.get('.ProbeServerModal input[name="uri"]')
      .type('{selectall}localhost:13301{enter}');
    cy.get('.ProbeServerModal').should('not.exist');
    cy.get('#root').contains('Probe is OK').click();
  })

  it('3. Edit replicaset dialog',() => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('li').contains('test-replicaset').closest('li').find('button').contains('Edit').click({ force: true });

    // I.
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type(' ');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');

    // II.
    cy.get('.meta-test__EditReplicasetModal input[name="alias"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Allowed symbols are: a-z, A-Z, 0-9, _ . -').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');

    // III.
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]')
      .type('q');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.disabled');

    // IV.
    cy.get('.meta-test__EditReplicasetModal input[name="weight"]')
      .type('{selectall}{backspace}');
    cy.get('.meta-test__EditReplicasetModal').contains('Field accepts number').should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').should('be.enabled');

    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('.meta-test__EditReplicasetModal').should('not.exist');
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
    cy.get('.meta-test__UserAddForm input[name="password"]').focus();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email').should('not.exist');

    cy.get('.meta-test__UserAddForm input[name="username"]')
      .type('username');
    cy.get('.meta-test__UserAddForm input[name="password"]')
      .type('qwerty{enter}');
    cy.get('.meta-test__UserAddForm').should('not.exist');
  })

});
