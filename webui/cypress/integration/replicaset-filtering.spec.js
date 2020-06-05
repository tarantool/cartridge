const testPort4 = `:13304`;
const localhost10 = `localhost:13310`;


describe('Replicaset filtering', () => {

  before(function () {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
  })

  it('Stop servers', () => {
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8084 -t)', { failOnNonZeroExit: true });
    cy.exec('kill -SIGSTOP $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
  })

  it('Filter in replicaset list', () => {
    //Healthy
    cy.get('button[type="button"]:contains(Filter)').click();
    cy.get('li:contains(Healthy)').click();
    cy.get('.meta-test__Filter input').should('have.value', 'status:healthy');
    cy.get('.ServerLabelsHighlightingArea').contains(testPort4).should('not.exist');

    //Unhealthy
    cy.get('button[type="button"]:contains(Filter)').click();
    cy.get('li:contains(Unhealthy)').click();
    cy.get('.meta-test__Filter input').should('have.value', 'status:unhealthy');
    cy.get('.ServerLabelsHighlightingArea').contains(testPort4);

    //Role
    cy.get('button[type="button"]:contains(Filter)').click();
    cy.get('.meta-test__Filter__Dropdown').find('li:contains(vshard-storage)').click();
    cy.get('.meta-test__Filter input').should('have.value', 'role:vshard-storage');
    cy.get('.ServerLabelsHighlightingArea').contains(testPort4);
    cy.get('#root').contains('storage1-do-not-use-me');
    cy.get('#root').contains('router1-do-not-use-me').should('not.exist');

    //Clear filter
    cy.get('.meta-test__Filter svg').eq(1).click();

    //Search
    cy.get('.meta-test__Filter').find('input').type(testPort4);
    cy.get('#root').contains('storage1-do-not-use-me');
    cy.get('#root').contains('router1-do-not-use-me').should('not.exist');
  })

  it('Filter in join replicaset dialog', () => {

    cy.get('li').contains(localhost10).closest('li').find('button')
      .contains('Configure').click();
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();

    //Healthy
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('li:contains(Healthy)').click();
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input')
      .should('have.value', 'status:healthy');
    cy.get('.meta-test__ConfigureServerModal').contains('storage1-do-not-use-me')
      .should('not.exist');

    // //Unhealthy
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('li:contains(Unhealthy)').click();
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input')
      .should('have.value', 'status:unhealthy');
    cy.get('.meta-test__ConfigureServerModal').contains('router1-do-not-use-me')
      .should('not.exist');

    // //Role
    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Filter)').click();
    cy.get('li:contains(vshard-router)').click();
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter input')
      .should('have.value', 'role:vshard-router');
    cy.get('.meta-test__ConfigureServerModal').contains('storage1-do-not-use-me')
      .should('not.exist');

    //Clear filter
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter svg').eq(1).click();

    // //Search
    cy.get('.meta-test__ConfigureServerModal .meta-test__Filter').find('input')
      .type('storage1-do-not-use-me');
    cy.get('.meta-test__ConfigureServerModal').contains('storage1-do-not-use-me');
    cy.get('.meta-test__ConfigureServerModal').contains('router1-do-not-use-me').should('not.exist');

    cy.get('.meta-test__ConfigureServerModal button[type="button"]:contains(Cancel)').click();
  })

  it('Rusurrect servers', () => {
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8084 -t)', { failOnNonZeroExit: true });
    cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :8082 -t)', { failOnNonZeroExit: true });
  })

})
