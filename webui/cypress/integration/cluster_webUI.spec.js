describe('Test cluster WEB_UI', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

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
          alias = 'test-storage-nothealthy',
          roles = {'vshard-storage'},
          servers = 2,
        }, {
          uuid = helpers.uuid('c'),
          alias = 'test-storage-healthy',
          roles = {'vshard-storage'},
          all_rw = true,
          servers = 1,
        }}
      })

      _G.cluster:start()
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      _G.cluster:server('test-storage-nothealthy-1'):stop()

      return true
    `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: update cluster WEB_UI correct tooltips', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Prepare for the test');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('button:contains("Review")').click();
    cy.get('button:contains("Disable")').click();
    cy.wait(1000);

    //Check tooltip on the page cluster
    cy.get('.meta-test__youAreHereIcon use').trigger('mouseover');
    cy.get('div').contains('WebUI operates here');

    cy.get('button[data-cy="meta-test__editBtn"]').eq(1).trigger('mouseover');
    cy.get('div').contains('Edit replica set');

    cy.get('div[data-cy="meta-test__replicaSetSection"] :nth-child(5) :nth-child(1)').eq(0).trigger('mouseover');
    cy.get('div').contains('Storage group');

    cy.get('div[data-cy="meta-test__replicaSetSection"] :nth-child(5) :nth-child(2)').eq(0).trigger('mouseover');
    cy.get('div').contains('Replica set weight');

    cy.get('div[data-cy="meta-test__replicaSetSection"] :nth-child(5) :nth-child(3)').eq(0).trigger('mouseover');
    cy.get('div').contains('All instances in the replicaset writeable');

    cy.get('div[data-component="ReplicasetListBuckets"]').eq(0).trigger('mouseover');
    cy.get('div').contains('Total bucket: 3000');

    cy.get('div[data-component="ReplicasetListMemStat"]').eq(1).trigger('mouseover');
    cy.get('div').contains('Memory usage: 1.4 MiB / 256.0 MiB');
  });
});
