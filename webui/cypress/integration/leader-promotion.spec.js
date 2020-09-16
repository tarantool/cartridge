describe('Leader promotion tests', () => {

  before(() => {
    cy.task('tarantool', {code: `
      cleanup()

      local workdir = fio.tempdir()
      fio.mktree(workdir)
      _G.server = require('luatest.server'):new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = workdir,
        net_box_port = 14401,
        net_box_credentials = {
          user = 'client',
          password = 'password',
        },
        env = {
          TARANTOOL_LOCK_DELAY = 1,
          TARANTOOL_PASSWORD = 'password',
        },
      })
      _G.server:start()
      helpers.retrying({}, function()
          _G.server:connect_net_box()
      end)

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),
        env = {
            TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
            TARANTOOL_APP_NAME = 'cartridge-testing',
        },
        replicasets = {{
          uuid = helpers.uuid('a'),
          alias = 'test-router',
          roles = {'vshard-router', 'failover-coordinator'},
          servers = {{http_port = 8080}},
        }, {
          uuid = helpers.uuid('b'),
          alias = 'test-storage',
          roles = {'vshard-storage'},
          servers = 2,
        }}
      })

      _G.cluster:start()
      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  function toggle_to_valid_stateboard() {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click({ force: true });
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:14401');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}password');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();
  }

  it('Preparation for the test', () => {
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica sets');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
  })

  it('The "Promote a leader" button should be absent in disable mode', () => {
    cy.get('li').contains('13301').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').should('not.exist');

    cy.get('li').contains('13303').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').should('not.exist');
  })

  it('The "Promote a leader" button should be absent in eventual mode', () => {
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__eventualRadioBtn').click();
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(eventual)').click();

    cy.get('li').contains('13301').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').should('not.exist');

    cy.get('li').contains('13303').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').should('not.exist');
  })

  it('The "Promote a leader" button in stateful mode + success when promote a leader', () => {
    toggle_to_valid_stateboard()

    cy.get('li').contains('13301').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').should('not.exist');

    cy.get('.ServerLabelsHighlightingArea').contains('13302').closest('li')
      .find('.meta-test_leaderFlag');
    cy.get('.ServerLabelsHighlightingArea').contains('13303').closest('li')
      .find('.meta-test_leaderFlag').should('not.exist');
    cy.get('li').contains('13303').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').click();
    cy.get('.ServerLabelsHighlightingArea').contains('13302').closest('li')
      .find('.meta-test_leaderFlag').should('not.exist');
    cy.get('.ServerLabelsHighlightingArea').contains('13303').closest('li')
      .find('.meta-test_leaderFlag');
  })

  it('Leader flag moves in failover priority', () => {
    cy.get('li').contains('test-storage').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__FailoverServerList:contains(13303)').closest('div').find('.meta-test__LeaderFlag');
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
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();

    cy.get('li').contains('13302').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown :contains(Promote a leader)').click({ force: true });
    cy.get('span:contains(Leader promotion error) + span:contains(StateProviderError: State provider unavailable)')
      .click();
  })

  it('Error "There is no active coordinator" when promote a leader', () => {
    //uncheck failover-coordinator role
    cy.get('li').contains('test-router').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .uncheck({ force: true });
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .should('not.be.checked');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    toggle_to_valid_stateboard()

    cy.get('li').contains('13302').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown :contains(Promote a leader)').click({ force: true });
    cy.get('span:contains(Leader promotion error) + span:contains(PromoteLeaderError: There is no active coordinator)')
      .click();
  })

});
