describe('Failover', () => {

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
          alias = 'dummy',
          roles = {},
          servers = {{http_port = 8080}, {}},
        }}
      })

      _G.cluster:start()
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      return true
    `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  function statefulInputsShouldNotExist() {
    cy.get('span:contains(Fencing)').should('not.exist');
    cy.get('span:contains(Enabled)').should('not.exist');
    cy.get('.meta-test__fencingTimeout').should('not.exist');
    cy.get('.meta-test__fencingPause').should('not.exist');
    cy.get('.meta-test__stateProviderChoice').should('not.exist');
    cy.get('label:contains(URI)').should('not.exist');
    cy.get('label:contains(Password)').should('not.exist');
  }

  it('Test: failover', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__FailoverButton').should('be.visible');
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');

    ////////////////////////////////////////////////////////////////////
    cy.log('Failover Disabled: modal before changing');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();

    statefulInputsShouldNotExist;

    cy.get('.meta-test__disableRadioBtn input').should('be.checked');
    cy.get('.meta-test__eventualRadioBtn input').should('not.be.checked');
    cy.get('.meta-test__statefulRadioBtn input').should('not.be.checked');

    //change Failover timeout
    cy.get('.meta-test__failoverTimeout input').should('have.value', '0');
    cy.get('.meta-test__failoverTimeout input').type('{selectAll}{del}q');
    cy.get('.meta-test__failoverTimeout p').contains('Field accepts number, ex: 0, 1, 2.43...');
    cy.get('.meta-test__failoverTimeout input').type('{selectAll}{del}5');
    cy.get('.meta-test__failoverTimeout p:contains(Field accepts number)').should('not.exist');
    cy.get('.meta-test__failoverTimeout input').should('have.value', '5');

    //Failover timeout tooltip
    cy.get('label:contains(Failover timeout)').next().trigger('mouseover');
    cy.get('div').contains('Timeout in seconds to mark suspect members as dead and trigger failover');

    //Failover mode tooltip
    cy.get('span:contains(Failover mode)').next().trigger('mouseover');
    cy.get('div').contains('Disabled');
    cy.get('div').contains('The leader is the first instance according to topology configuration. ' +
      'No automatic decisions are taken.');
    cy.get('div').contains('Eventual');
    cy.get('div').contains('The leader isn\'t elected consistently. Every instance thinks the leader' +
      ' is the first healthy server in the replicaset. The instance health is determined according to' +
      ' the membership status (the SWIM protocol).');
    cy.get('div').contains('Stateful:');
    cy.get('div').contains('Leader appointments are polled from the external state provider. ' +
      'Decisions are taken by one of the instances with the failover-coordinator role enabled.');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__FailoverModal').should('not.exist');
    cy.get('span:contains(Failover mode) + span:contains(disabled) + svg').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: disabled');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');

    ////////////////////////////////////////////////////////////////////
    cy.log('Failover Eventual');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__eventualRadioBtn').click();

    statefulInputsShouldNotExist();

    cy.get('.meta-test__disableRadioBtn input').should('not.be.checked');
    cy.get('.meta-test__eventualRadioBtn input').should('be.checked');
    cy.get('.meta-test__statefulRadioBtn input').should('not.be.checked');

    cy.get('.meta-test__failoverTimeout input').should('have.value', '5');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(eventual) + svg').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: eventual');
    cy.get('.meta-test__ClusterIssuesButton').should('be.disabled');

    ////////////////////////////////////////////////////////////////////
    cy.log('Failover Stateful - TARANTOOL: error');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__statefulRadioBtn').click();

    cy.get('.meta-test__disableRadioBtn input').should('not.be.checked');
    cy.get('.meta-test__eventualRadioBtn input').should('not.be.checked');
    cy.get('.meta-test__statefulRadioBtn input').should('be.checked');

    //Fencing tooltip
    cy.get('span:contains(Fencing)').next().trigger('mouseover');
    cy.get('div').contains('A leader will go read-only when both the state provider ' +
      'and one of replicas are unreachable');

    //Fencing disable
    cy.get('.meta-test__fencingEnableCheckbox input').should('not.be.checked');
    cy.get('.meta-test__fencingTimeout input').should('be.disabled').should('have.value', '10');
    cy.get('.meta-test__fencingPause input').should('be.disabled').should('have.value', '2');

    //Fencing timeout tooltip
    cy.get('label:contains(Fencing timeout)').next().trigger('mouseover');
    cy.get('div').contains('Time in seconds to actuate the fencing after the health check fails');

    //Fencing pause tooltip
    cy.get('label:contains(Fencing pause)').next().trigger('mouseover');
    cy.get('div').contains('The period in seconds of performing the health check');

    //Fencing enable
    cy.get('.meta-test__fencingEnableCheckbox input').click({ force: true });
    cy.get('.meta-test__fencingEnableCheckbox input').should('be.checked');
    //change Fencing timeout
    cy.get('.meta-test__fencingTimeout input').should('be.enabled');
    cy.get('.meta-test__fencingTimeout input').type('{selectAll}{del}q');
    cy.get('.meta-test__fencingTimeout p').contains('Field accepts number, ex: 0, 1, 2.43...');
    cy.get('.meta-test__fencingTimeout input').type('{selectAll}{del}11');
    cy.get('.meta-test__fencingTimeout input').should('have.value', '11');
    cy.get('.meta-test__fencingTimeout p:contains(Field accepts number)').should('not.exist');
    //change Fencing pause
    cy.get('.meta-test__fencingPause input').should('be.enabled');
    cy.get('.meta-test__fencingPause input').type('{selectAll}{del}q');
    cy.get('.meta-test__fencingPause p').contains('Field accepts number, ex: 0, 1, 2.43...');
    cy.get('.meta-test__fencingPause input').type('{selectAll}{del}3');
    cy.get('.meta-test__fencingPause input').should('have.value', '3');
    cy.get('.meta-test__fencingPause p:contains(Field accepts number)').should('not.exist');

    //State provider: Tarantool (stateboard)
    cy.get('button[label="State provider"]').contains('Tarantool (stateboard)').click();
    cy.get('.meta-test__StateProvider__Dropdown *:contains(Tarantool (stateboard))');
    cy.get('.meta-test__StateProvider__Dropdown *:contains(Etcd)');
    cy.get('.meta-test__stateboardURI input').should('have.value', 'tcp://localhost:4401');
    cy.get('.meta-test__stateboardPassword input').should('have.value', '');
    //error failover_timeout must be greater than fencing_timeout
    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__inlineError span').should('have.text',
      'topology_new.failover.failover_timeout must be greater than fencing_timeout'
    );
    //error Invalid URI ""
    cy.get('.meta-test__stateboardURI input').type('{selectAll}{del}');
    cy.get('.meta-test__fencingTimeout input').type('{selectAll}{del}4');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__inlineError span').should('have.text',
      'topology_new.failover.tarantool_params.uri: Invalid URI ""'
    );
    //error Invalid URI "" (missing port)
    cy.get('.meta-test__stateboardURI input').type('qq');
    cy.get('.meta-test__stateboardURI input').should('have.value', 'qq');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__inlineError span').should('have.text',
      'topology_new.failover.tarantool_params.uri: Invalid URI "qq" (missing port)'
    );

    //There is no Etcd inputs
    cy.get('.meta-test__etcd2Endpoints').should('not.exist');
    cy.get('.meta-test__etcd2LockDelay').should('not.exist');
    cy.get('.meta-test__etcd2Prefix').should('not.exist');
    cy.get('.meta-test__etcd2Username').should('not.exist');
    cy.get('.meta-test__etcd2Password').should('not.exist');

    cy.get('.meta-test__CancelButton').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Failover Stateful - TARANTOOL: success');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();

    cy.get('.meta-test__inlineError').should('not.exist');

    cy.get('.meta-test__statefulRadioBtn').click();
    cy.get('.meta-test__fencingEnableCheckbox input').click({ force: true });
    cy.get('.meta-test__fencingTimeout input').type('{selectAll}{del}4');

    cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:14401');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful) + svg').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');

    ////////////////////////////////////////////////////////////////////
    cy.log('Failover Stateful - ETCD: success');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click();
    cy.get('button[label="State provider"]').contains('Tarantool (stateboard)').click();
    cy.get('.meta-test__StateProvider__Dropdown *:contains(Etcd)').click();
    cy.get('button[label="State provider"]').contains('Etcd')

    cy.get('.meta-test__etcd2Endpoints textarea')
      .should('have.text', 'http://127.0.0.1:4001\nhttp://127.0.0.1:2379');
    cy.get('.meta-test__etcd2LockDelay input').should('have.value', '10');
    cy.get('.meta-test__etcd2Prefix input').should('have.value', '/');
    cy.get('.meta-test__etcd2Username input').should('have.value', '');
    cy.get('.meta-test__etcd2Password input').should('have.value', '');

    cy.get('.meta-test__SubmitButton').click();
    cy.get('span:contains(Failover mode) + span:contains(stateful) + svg').click();
    cy.get('.meta-test__FailoverButton').contains('Failover: stateful');

    //There is no Tarantool (stateboard) inputs
    cy.get('.meta-test__stateboardURI').should('not.exist');
    cy.get('.meta-test__stateboardPassword').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Failover Stateful - ETCD: errors');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__FailoverButton').click();
    cy.get('.meta-test__statefulRadioBtn').click();

    cy.get('.meta-test__etcd2Endpoints textarea').type('{selectAll}{del}qq');
    cy.get('.meta-test__SubmitButton').click();
    cy.get('.meta-test__inlineError span').should('have.text',
      'topology_new.failover.etcd2_params.endpoints[1]: Invalid URI "qq" (missing port)'
    );

    cy.get('.meta-test__etcd2LockDelay input').type('{selectAll}{del}qq');
    cy.get('.meta-test__etcd2LockDelay').next().contains('Field accepts number, ex: 0, 1, 2.43...');
    cy.get('.meta-test__etcd2LockDelay input').type('{selectAll}{del}10');
    cy.get('.meta-test__etcd2LockDelay').next().contains('Field accepts number)').should('not.exist');

    cy.get('.meta-test__CancelButton').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Check issues');
    ////////////////////////////////////////////////////////////////////
    cy.contains('Replica sets');
    cy.get('.meta-test__ClusterIssuesButton').should('be.enabled');
    cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 4');
    cy.get('.meta-test__ClusterIssuesButton').click();

    cy.get('.meta-test__ClusterIssuesModal')
      .contains('warning: Can\'t obtain failover coordinator: ');
    cy.get('.meta-test__ClusterIssuesModal button[type="button"]').click();
    cy.get('.meta-test__ClusterIssuesModal').should('not.exist');

    cy.get('.meta-test__haveIssues').click();
    cy.get('.meta-test__ClusterIssuesModal').contains('Issues: 1');
    cy.get('.meta-test__ClusterIssuesModal').contains(
      'warning: Consistency on localhost:13301 (dummy-1) isn\'t reached yet'
    );
  });
});
