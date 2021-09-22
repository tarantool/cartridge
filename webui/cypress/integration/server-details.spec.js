describe('Server details', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()

        _G.cluster = helpers.Cluster:new({
          datadir = fio.tempdir(),
          server_command = helpers.entrypoint('srv_basic'),
          use_vshard = false,
          cookie = helpers.random_cookie(),
          replicasets = {{
            uuid = helpers.uuid('a'),
            alias = 'dummy',
            roles = {},
            servers = {{http_port = 8080}, {}},
          }},
        })

        _G.cluster:start()
        _G.cluster.main_server.net_box:call(
          'package.loaded.cartridge.failover_set_params',
          {{failover_timeout = 0}}
        )
        return true
      `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function openServerDetailsModal(serverAlias) {
    cy.get('li').contains(serverAlias).closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Server details').click();
  }

  function checkServerDetailsTabs() {
    cy.get('.meta-test__ServerDetailsModal button').contains('Cartridge').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Replication').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Storage').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Network').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('General').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Membership').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Vshard-Router').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Vshard-Storage').click();
    cy.get('.meta-test__ServerDetailsModal button').contains('Issues 0').click();
  }

  function checkRedCircleBeforeSelectedZone(itemName, color) {
    cy.get('.meta-test__ZoneListItem').contains(itemName)
      .then(($els) => {
        const win = $els[0].ownerDocument.defaultView;
        // read the pseudo selector
        const before = win.getComputedStyle($els[0], 'before');
        // read the value of the content CSS property
        const contentValue = before.getPropertyValue('background-color');
        expect(contentValue).to.eq(color);
      })
  }

  it('Test: serever-details', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Alive server');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');

    openServerDetailsModal('dummy-1');
    checkServerDetailsTabs();

    cy.get('.meta-test__ServerDetailsModal').closest('div').find('.meta-test__youAreHereIcon');

    //add new zone Narnia
    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('div').contains('You have no any zone,');
    cy.get('div').contains('please add one.');
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="zone_name"]').should('be.focused').type('Narnia');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.ZoneAddModal').should('not.exist');
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Narnia)');

    cy.get('.meta-test__ServerDetailsModal button:contains(Zone Narnia)').click();
    checkRedCircleBeforeSelectedZone('Narnia','rgb(245, 34, 45)');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
    cy.get('.meta-test__ServerDetailsModal').should('not.exist');

    //checks for dummy-2
    cy.log('checks for dummy-2');
    openServerDetailsModal('dummy-2');
    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('div').contains('You have no any zone,').should('not.exist');

    //check red circle is not before not elected zone
    checkRedCircleBeforeSelectedZone('Narnia','rgba(0, 0, 0, 0)');
    cy.get('.meta-test__ZoneListItem:contains(Narnia)').click();
    cy.get('.meta-test__ServerDetailsModal button:contains(Zone Narnia)').click();
    checkRedCircleBeforeSelectedZone('Narnia','rgb(245, 34, 45)');
    // cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Narnia)').click();

    //add new zone Mordor
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="zone_name"]').should('be.focused').type('Mordor');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.ZoneAddModal').should('not.exist');
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Mordor)');

    //check red circle is before new zone
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Mordor)').click();
    checkRedCircleBeforeSelectedZone('Narnia','rgba(0, 0, 0, 0)');
    checkRedCircleBeforeSelectedZone('Mordor','rgb(245, 34, 45)');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    //delete zone Narnia
    openServerDetailsModal('dummy-1');
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Narnia)').click();
    cy.get('div').contains('Mordor');
    checkRedCircleBeforeSelectedZone('Narnia','rgb(245, 34, 45)');
    checkRedCircleBeforeSelectedZone('Mordor','rgba(0, 0, 0, 0)');
    cy.get('.meta-test__ZoneListItem:contains(Narnia)').click();
    cy.get('.meta-test__ServerDetailsModal button:contains(Select zone)').click();
    cy.get('button:contains(Add new zone)').should('be.enabled');
    cy.get('div').contains('Mordor');
    cy.get('div').contains('Narnia').should('not.exist');
    checkRedCircleBeforeSelectedZone('Mordor','rgba(0, 0, 0, 0)');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
    openServerDetailsModal('dummy-2');
    cy.get('.meta-test__ServerDetailsModal button:contains(Zone Mordor)').click();
    cy.get('div').contains('Mordor');
    checkRedCircleBeforeSelectedZone('Mordor','rgb(245, 34, 45)');
    cy.get('div').contains('Narnia').should('not.exist');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    // Enable/disable servers
    openServerDetailsModal('dummy-1');
    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();

    // Disable leader: will fail
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Disable server').click();
    cy.get(
      'span:contains(Invalid cluster topology config: Current instance "localhost:13301" can not be disabled)'
    ).click();
    cy.get('.meta-test__ServerDetailsModal  span:contains(Disabled)').should('not.exist');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    openServerDetailsModal('dummy-2');

    // Disable replica: will succeed
    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Disable server').click();
    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('exist');

    // Enable replica back: will succeed
    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Enable server').click();
    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('not.exist');

    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Dead server');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', {
      code: `
      _G.cluster:server('dummy-2').process:kill('KILL')
      _G.cluster:server('dummy-2').process = nil
    `,
    });

    cy.get('.ServerLabelsHighlightingArea')
      .contains('dummy-2')
      .closest('li')
      .should('contain', 'Server status is "dead"');

    openServerDetailsModal('dummy-2');
    cy.get('.meta-test__ServerDetailsModal button:contains(Zone Mordor)').click();

    cy.get('div').contains('Mordor').should('exist');
    cy.get('.meta-test__ZoneListItem').contains('Mordor').click();
    cy.get('span:contains(NetboxCallError: "localhost:13302":)').click();

    cy.get('.meta-test__ServerDetailsModal button:contains(Zone Mordor)').click();
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="zone_name"]').should('be.focused').type('Moscow');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.ZoneAddModal_error').find('span:contains("localhost:13302":)');
    cy.get('h2:contains(Add name of zone)').next().click();
    cy.get('.ZoneAddModal').should('not.exist');

    cy.get('.meta-test__ServerDetailsModal').contains('Server status is "dead"');
    cy.get('.meta-test__ServerDetailsModal').contains('instance_uuid').should('not.exist');

    checkServerDetailsTabs();
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    // Enable/disable servers
    openServerDetailsModal('dummy-2');

    // Disable dead replica: will succeed
    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Disable server').click();
    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('exist');

    // Enable dead replica: will fail
    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Enable server').click();
    cy.get('span:contains(NetboxCallError: "localhost:13302":)').click();
    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('exist');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
    // Enable/disable servers - end

    cy.task('tarantool', { code: `_G.cluster:server('dummy-2'):start()` });
    openServerDetailsModal('dummy-2');
    cy.get('.meta-test__ServerDetailsModal').contains('healthy');
    cy.get('.meta-test__ServerDetailsModal').contains('instance_uuid');

    cy.get('.meta-test__ServerDetailsModal button:contains(Zone Mordor)').click();
    cy.get('button:contains(Add new zone)').click();
    cy.get('.ZoneAddModal input[name="zone_name"]').should('be.focused').type('Rostov');
    cy.get('.meta-test__ZoneAddSubmitBtn').click();
    cy.get('.meta-test__ServerDetailsModal').find('button:contains(Zone Rostov)');

    cy.task('tarantool', { code: `return _G.cluster:server('dummy-2').instance_uuid` }).then((resp) => {
      const uuid = resp[0];
      cy.get('.meta-test__ServerDetailsModal').contains(uuid);
    });

    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();
  });
});
