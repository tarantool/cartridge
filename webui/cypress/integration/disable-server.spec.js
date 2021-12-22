describe('Disable server', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()

        _G.cluster = helpers.Cluster:new({
          datadir = fio.tempdir(),
          server_command = helpers.entrypoint('srv_basic'),
          use_vshard = false,
          cookie = helpers.random_cookie(),
          env = {TARANTOOL_REPLICATION_CONNECT_QUORUM = 0},
          replicasets = {{
            uuid = helpers.uuid('a'),
            alias = 'dummy',
            roles = {},
            servers = {{http_port = 8080}, {}, {}},
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

  it('Test: disable-server', () => {
    cy.visit('/admin/cluster/dashboard');
    cy.get('h1:contains(Cluster)');

    ////////////////////////////////////////////////////////////////////
    cy.log('All servers are alive and healthy');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should(
      'have.css',
      'background-color',
      'rgb(255, 255, 255)'
    );
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should(
      'have.css',
      'background-color',
      'rgb(255, 255, 255)'
    );

    ///////////////////////////////////////////////////////////////////
    cy.log('Information about healthy and unhealthy server count before disabling server 2 and 3');
    ////////////////////////////////////////////////////////////////////
    cy.get('[data-component=ReplicasetListHeader]').contains('Healthy1');
    cy.get('[data-component=ReplicasetListHeader]').contains('Unhealthy0');
    cy.get('[data-cy=meta-test__replicaSetSection]').contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(2).contains('healthy');

    ////////////////////////////////////////////////////////////////////
    cy.log('Kill servers 2 and 3');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', {
      code: `
      _G.cluster:server('dummy-2').process:kill('KILL')
      _G.cluster:server('dummy-3').process:kill('KILL')
      _G.cluster:server('dummy-2').process = nil
      _G.cluster:server('dummy-3').process = nil
    `,
    });

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion panel');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('be.visible');
    cy.get('.meta-test__ClusterSuggestionsPanel h5').contains('Disable instances');
    cy.get('.meta-test__ClusterSuggestionsPanel span').contains(
      'Some instances are malfunctioning' +
        ' and impede editing clusterwide configuration.' +
        ' Disable them temporarily if you want to operate topology.'
    );

    //Check health state for Servers and  ReplicaSet
    cy.get('[data-component=ReplicasetListHeader]').contains('Healthy0');
    cy.get('[data-component=ReplicasetListHeader]').contains('Unhealthy1');
    cy.get('[data-cy=meta-test__replicaSetSection]').contains('have issues');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('unreachable');
    cy.get('.ServerLabelsHighlightingArea')
      .eq(1)
      .find('[data-component=ReplicasetListStatus]')
      .invoke('attr', 'data-value-message')
      .should('eq', 'Server status is "dead"');
    cy.get('.ServerLabelsHighlightingArea').eq(2).contains('unreachable');
    cy.get('.ServerLabelsHighlightingArea')
      .eq(2)
      .find('[data-component=ReplicasetListStatus]')
      .invoke('attr', 'data-value-message')
      .should('eq', 'Server status is "dead"');
    ////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////
    cy.log('Inspect suggestion modal');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel button').contains('Review').click();
    cy.get('.meta-test__DisableServersSuggestionModal h2').contains('Disable instances');
    cy.get('.meta-test__DisableServersSuggestionModal p').contains(
      'Some instances are malfunctioning' +
        ' and impede editing clusterwide configuration.' +
        ' Disable them temporarily if you want to operate topology.'
    );
    cy.get('.meta-test__DisableServersSuggestionModal li').contains('localhost:13302 (dummy-2)');
    cy.get('.meta-test__DisableServersSuggestionModal li').contains('localhost:13303 (dummy-3)');
    cy.get('.meta-test__DisableServersSuggestionModal button').contains('Disable').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Servers 2 and 3 are disabled');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should(
      'have.css',
      'background-color',
      'rgb(250, 250, 250)'
    );
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should(
      'have.css',
      'background-color',
      'rgb(250, 250, 250)'
    );

    ////////////////////////////////////////////////////////////////////
    cy.log(
      'Inspect correct information for healthy and unhealthy server count after server 2 and 3 have been disabled'
    );
    ////////////////////////////////////////////////////////////////////
    cy.get('[data-component=ReplicasetListHeader]').contains('Healthy0');
    cy.get('[data-component=ReplicasetListHeader]').contains('Unhealthy1');
    cy.get('[data-cy=meta-test__replicaSetSection]').contains('unhealthy');

    ////////////////////////////////////////////////////////////////////
    cy.log('Try to enable dead server via dropdown button');
    ////////////////////////////////////////////////////////////////////
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
      .click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Enable server').click();
    cy.get(
      'span:contains(Disabled state setting error) +' + 'span:contains(NetboxCallError: "localhost:13302":)'
    ).click();
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should(
      'have.css',
      'background-color',
      'rgb(250, 250, 250)'
    );

    ////////////////////////////////////////////////////////////////////
    cy.log('Try to enable dead server via server details');
    ////////////////////////////////////////////////////////////////////
    cy.get('a:contains(dummy-3)').click();
    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Enable server').click();
    cy.get(
      'span:contains(Disabled state setting error) +' + 'span:contains(NetboxCallError: "localhost:13303":)'
    ).click();
    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('exist');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Enable server 2 via dropdown button');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', { code: `_G.cluster:server('dummy-2'):start()` });
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').contains('healthy');

    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)')
      .find('.meta-test__ReplicasetServerListItem__dropdownBtn')
      .click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Enable server').click();

    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should(
      'have.css',
      'background-color',
      'rgb(255, 255, 255)'
    );
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
    cy.get('[data-cy=meta-test__replicaSetSection]').contains('unhealthy');

    ////////////////////////////////////////////////////////////////////
    cy.log('Enable server 3 via server details');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', { code: `_G.cluster:server('dummy-3'):start()` });
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').contains('healthy');

    cy.get('a:contains(dummy-3)').click();
    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('exist');

    cy.get('.meta-test__ServerDetailsModal .meta-test__ReplicasetServerListItem__dropdownBtn').click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown div').contains('Enable server').click();

    cy.get('.meta-test__ServerDetailsModal span:contains(Disabled)').should('not.exist');
    cy.get('.meta-test__ServerDetailsModal button').contains('Close').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('All servers are alive and healthy');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ClusterSuggestionsPanel').should('not.exist');
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-2)').should(
      'have.css',
      'background-color',
      'rgb(255, 255, 255)'
    );
    cy.get('.ServerLabelsHighlightingArea:contains(dummy-3)').should(
      'have.css',
      'background-color',
      'rgb(255, 255, 255)'
    );

    ///////////////////////////////////////////////////////////////////
    cy.log('Information about healthy and unhealthy server count after enableing server 2 and 3');
    ////////////////////////////////////////////////////////////////////
    cy.get('[data-component=ReplicasetListHeader]').contains('Healthy1');
    cy.get('[data-component=ReplicasetListHeader]').contains('Unhealthy0');
    cy.get('[data-cy=meta-test__replicaSetSection]').contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(0).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(1).contains('healthy');
    cy.get('.ServerLabelsHighlightingArea').eq(2).contains('healthy');
  });
});
