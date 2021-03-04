const greenIcon = `rgb(181, 236, 142)`;
const orangeIcon = `rgb(250, 173, 20)`;

describe('Leader promotion tests', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.server = require('luatest.server'):new({
        command = helpers.entrypoint('srv_stateboard'),
        workdir = fio.tempdir(),
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
      fio.mktree(_G.server.workdir)
      _G.server:start()
      helpers.retrying({}, function()
          _G.server:connect_net_box()
      end)

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),
        env = {TARANTOOL_APP_NAME = 'cartridge-testing'},
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

      _G.cluster:server('test-storage-1').env.TARANTOOL_CONSOLE_SOCK =
        _G.cluster.datadir .. '/s-1.control'
      _G.cluster:start()
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      return true
    `}).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function dropdownMenu(port) {
    cy.get('li').contains(port).closest('li')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
      .click({ force: true });
    return cy.get('.meta-test__ReplicasetServerListItem__dropdown *');
  }

  function leaderFlag(port) {
    return cy.get('.ServerLabelsHighlightingArea').contains(port).closest('li')
      .find('.meta-test_leaderFlag use')
  }

  it('Test: switchover', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Prepare for the test');
    ////////////////////////////////////////////////////////////////////
    cy.visit(Cypress.config('baseUrl') + '/admin/cluster/dashboard');
    cy.contains('Replica sets');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');

    ////////////////////////////////////////////////////////////////////
    cy.log('Leader promotion unavailable in disable mode');
    ////////////////////////////////////////////////////////////////////
    dropdownMenu('13301').contains('Promote a leader').should('not.exist');
    dropdownMenu('13302').contains('Promote a leader').should('not.exist');
    dropdownMenu('13303').contains('Promote a leader').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Leader promotion unavailable in eventual mode');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__eventualRadioBtn').click();
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(eventual)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');

    dropdownMenu('13301').contains('Promote a leader').should('not.exist');
    dropdownMenu('13302').contains('Promote a leader').should('not.exist');
    dropdownMenu('13303').contains('Promote a leader').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Leader promotion is available in stateful mode');
    ////////////////////////////////////////////////////////////////////

    // Enable stateful failover mode
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click({ force: true });
    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:14401');
    cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}password');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful)').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');

    leaderFlag('13302').invoke('css', 'fill', greenIcon);
    leaderFlag('13303').should('not.exist');

    dropdownMenu('13301').contains('Promote a leader').should('not.exist');
    dropdownMenu('13302').contains('Promote a leader').should('not.exist');
    dropdownMenu('13303').contains('Promote a leader').click();
    cy.get('span:contains(Failover) + span:contains(Leader promotion successful)').click();

    leaderFlag('13302').should('not.exist');
    leaderFlag('13303').invoke('css', 'fill', greenIcon);

    cy.get('li').contains('test-storage').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__FailoverServerList:contains(13303)').closest('div').find('.meta-test__LeaderFlag');
    cy.get('.meta-test__FailoverServerList:contains(13302)').closest('div').find('.meta-test__LeaderFlag')
      .should('not.exist');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    dropdownMenu('13302').contains('Promote a leader').click();
    cy.get('span:contains(Failover) + span:contains(Leader promotion successful)').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('There is no active coordinator error');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');

    // Disable the failover-coordinator
    cy.get('li').contains('test-router').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .uncheck({ force: true });
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .should('not.be.checked');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    leaderFlag('13302').invoke('css', 'fill', greenIcon);
    leaderFlag('13303').should('not.exist');

    dropdownMenu('13303').contains('Promote a leader').click();
    cy.get('span:contains(Leader promotion error) + span:contains(PromoteLeaderError: There is no active coordinator)')
      .click();

    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesModal')
      .contains("warning: There is no active failover coordinator");
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    // Re-enable failover-coordinator
    cy.get('li').contains('test-router').closest('li').find('button').contains('Edit').click();
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .check({ force: true });
    cy.get('.meta-test__EditReplicasetModal input[name="roles"][value="failover-coordinator"]')
      .should('be.checked');
    cy.get('.meta-test__EditReplicasetSaveBtn').click();
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 0');

    ////////////////////////////////////////////////////////////////////
    cy.log('Restore consistency by force promote');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');

    cy.task('tarantool', {
      code: `
      _G.cluster:server('test-storage-1').env.TARANTOOL_CONSOLE_SOCK
    `}).then((resp) => {
        const sock = resp[0];
        expect(sock).to.be.a('string');
        cy.task('tarantool', {
          host: 'unix/', port: sock, code: `
        local failover = require('cartridge.failover')
        return failover.force_inconsistency({[box.info.cluster.uuid] = 'nobody2'})
      `}).should('deep.eq', [true]);
      });

    leaderFlag('13302').invoke('css', 'fill', greenIcon);
    leaderFlag('13303').should('not.exist');

    // Enable all-rw mode
    cy.get('li').contains('test-storage').closest('li').find('button').contains('Edit').click()
    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').check({ force: true })
    cy.get('.meta-test__EditReplicasetSaveBtn').click()
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    dropdownMenu('13303').contains('Promote a leader').click();
    cy.get('span:contains(Failover) + span:contains(Leader promotion successful)').click();

    leaderFlag('13302').should('not.exist');
    leaderFlag('13303').invoke('css', 'fill', greenIcon);

    // Disable all-rw mode
    cy.get('li').contains('test-storage').closest('li').find('button').contains('Edit').click()
    cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').uncheck({ force: true })
    cy.get('.meta-test__EditReplicasetSaveBtn').click()
    cy.get('span:contains(Edit is OK. Please wait for list refresh...)').click();

    dropdownMenu('13302').contains('Promote a leader').click();
    cy.get('span:contains(Leader promotion error) + span:contains(WaitRwError: timed out)').click();

    leaderFlag('13302').invoke('css', 'fill', orangeIcon);
    leaderFlag('13303').should('not.exist');

    cy.reload()
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesButton').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesModal').contains(
      "warning: Consistency on localhost:13302" +
      " (test-storage-1) isn't reached yet"
    );
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    leaderFlag('13302').invoke('css', 'fill', orangeIcon);
    leaderFlag('13303').should('not.exist');

    dropdownMenu('13302').contains('Force promote a leader').click();
    cy.get('span:contains(Failover) + span:contains(Leader promotion successful)').click();

    leaderFlag('13302').invoke('css', 'fill', greenIcon);
    leaderFlag('13303').should('not.exist');

    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 0');
  });
});
