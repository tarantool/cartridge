describe('Leader promotion tests', () => {

  function toggle_to_valid_stateboard() {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click();
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:14401');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}password');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + * + span:contains(stateful)').click();
  }

  before(function () {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica sets');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
  })

  it('The "Promote a leader" button should be absent in disable mode', () => {
    cy.get('li').contains('13301').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').should('not.exist');

    cy.get('li').contains('13304').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').should('not.exist');
  })

  it('The "Promote a leader" button should be absent in eventual mode', () => {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__eventualRadioBtn').click();
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + * + span:contains(eventual)').click();

    cy.get('li').contains('13301').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').should('not.exist');

    cy.get('li').contains('13304').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').should('not.exist');
  })

  it('The "Promote a leader" button in stateful mode + success when promote a leader', () => {
    toggle_to_valid_stateboard()

    cy.get('li').contains('13301').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').should('not.exist');

    cy.get('.ServerLabelsHighlightingArea').contains('13302').closest('li')
      .find('.meta-test_leaderFlag');
    cy.get('.ServerLabelsHighlightingArea').contains('13304').closest('li')
      .find('.meta-test_leaderFlag').should('not.exist');
    cy.get('li').contains('13304').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').click();
    cy.get('.ServerLabelsHighlightingArea').contains('13302').closest('li')
      .find('.meta-test_leaderFlag').should('not.exist');
    cy.get('.ServerLabelsHighlightingArea').contains('13304').closest('li')
      .find('.meta-test_leaderFlag');
  })

  it('Leader flag moves in failover priority', () => {
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__FailoverServerList:contains(13304)').closest('div').find('.meta-test__LeaderFlag');
    cy.get('.meta-test__FailoverServerList:contains(13302)').closest('div').find('.meta-test__LeaderFlag')
      .should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
  })

  it('Error "State provider unavailable" when promote a leader', () => {
    //toggle to invalid stateboard
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click().click();
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:13301');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + * + span:contains(stateful)').click();

    cy.get('li').contains('13302').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').click();
    cy.get('span:contains(Leader promotion error) + * + span:contains(GraphQL error: State provider unavailable)')
      .click();
  })

  it('Error "There is no active coordinator" when promote a leader', () => {
    //uncheck failover-coordinator role
    cy.get('li').contains('storage1-do-not-use-me').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .uncheck({ force: true });
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .should('not.be.checked');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    toggle_to_valid_stateboard()

    cy.get('li').contains('13302').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown').contains('Promote a leader').click();
    cy.get('span:contains(Leader promotion error) + * + span:contains(GraphQL error: There is no active coordinator)')
      .click();
  })

});
