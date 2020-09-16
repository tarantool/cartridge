describe('Consistent promotion', () => {

    before(() => {
        cy.task('tarantool', {
            code: `
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
            use_vshard = false,
            cookie = 'test-cluster-cookie',
            replicasets = {{
              uuid = helpers.uuid('a'),
              alias = 'a',
              roles = {},
              servers = {{http_port = 8080}, {}},
            }}
          })
    
          for _, server in ipairs(_G.cluster.servers) do
            server:start()
          end
    
          helpers.retrying({}, function()
            _G.cluster:server('a-1'):graphql({query = '{}'})
          end)
          return true
        `}).should('deep.eq', [true]);
    });

    after(() => {
        cy.task('tarantool', { code: `cleanup()` });
    });

    const testPort1 = `13301`
    const testPort2 = `13302`
    const statefulPort = `14401`
    const greenIcon = `rgb(181, 236, 142)`
    const orangeIcon = `rgb(250, 173, 20)`
    const testServer2Name = `a-2`

    //function forceInconsistency for ci:

    function forceInconsistency(port) {
        cy.exec('echo "require(\'cartridge.failover\').force_inconsistency({[box.info.cluster.uuid] = \'nobody2\'})" | ' +
            'tarantoolctl connect admin:test-cluster-cookie@localhost:' + port, {failOnNonZeroExit: false})
    }

    function checkIconColor(color, port) {
        cy.get('.ServerLabelsHighlightingArea').contains(port).closest('li')
            .find('.meta-test_leaderFlag use').invoke('css', 'fill', color)
    }

    it('Open WebUI', () => {
        cy.visit('/admin/cluster/dashboard')
    });

    it('Create conditions for test', () => {
        //create replica set
        cy.get('.meta-test__configureBtn').first().click()
        cy.get('.meta-test__ConfigureServerModal input[name="alias"]')
            .type('replica-set-for-test')
        cy.get('.meta-test__ConfigureServerModal button[type="button"]').contains('Select all').click()
        cy.get('.meta-test__CreateReplicaSetBtn').click()
        //join server to replica set
        cy.get('li').contains('localhost:' + testPort2).closest('li').find('button').contains('Configure').click({ force: true })
        cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click()
        cy.get('.meta-test__ConfigureServerModal input[name="replicasetUuid"]').check({ force: true })
        cy.get('.meta-test__JoinReplicaSetBtn').click()
        //stateful failover mode: on
        cy.get('.meta-test__FailoverButton').click()
        cy.get('.meta-test__statefulRadioBtn').click({ force: true })
        cy.get('.meta-test__stateboardURI input').type('{selectall}{backspace}localhost:' + statefulPort)
        cy.get('.meta-test__stateboardPassword input').type('{selectall}{backspace}password')
        cy.get('.meta-test__SubmitButton').click()
        cy.get('span:contains(Failover mode) + span:contains(stateful)').click()
    })

    it('Change leader', () => {
        cy.get('.meta-test__ClusterIssuesButton').should('be.disabled')

        checkIconColor(greenIcon, testPort1)
        forceInconsistency(testPort1)
        cy.get('li').contains(testPort2).closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click()
        cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').click()
        cy.get('span:contains(Leader promotion error) + span:contains(WaitRwError: timed out)').click()
        checkIconColor(orangeIcon, testPort2)
    })

    it('Issues checks before force promote', () => {
        cy.reload()
        cy.contains('replica-set-for-test', { timeout: 10000 })
        cy.get('.meta-test__ClusterIssuesButton').should('be.enabled')
        cy.get('.meta-test__ClusterIssuesButton').contains('Issues: 1')
        cy.get('.meta-test__ClusterIssuesButton').click()
        cy.get('.meta-test__ClusterIssuesModal', { timeout: 6000 })
            .contains('Consistency on localhost:' + testPort2 + ' (' + testServer2Name + ') isn\'t reached yet')
        cy.get('.meta-test__closeClusterIssuesModal').click()
        cy.get('li').contains('replica-set-for-test').closest('li').find('.meta-test__haveIssues')
    })

    it('Force promote a leader', () => {
        cy.get('li').contains(testPort2).closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click()
        cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Force promote a leader').click()
        cy.get('span:contains(Failover) + span:contains(Leader promotion successful)').click()
        checkIconColor(greenIcon, testPort2)
    })

    it('Issues checks after force promote', () => {
        cy.reload()
        cy.contains('replica-set-for-test', { timeout: 10000 })
        cy.get('.meta-test__ClusterIssuesButton').should('be.disabled')
        cy.get('.meta-test__haveIssues').should('not.exist')
    })

    it('If ALL RW checked', () => {
        cy.get('li').contains('replica-set-for-test').closest('li').find('button').contains('Edit').click()
        cy.get('.meta-test__EditReplicasetModal input[name="all_rw"]').check({ force: true })
        cy.get('.meta-test__EditReplicasetSaveBtn').click()

        forceInconsistency(testPort1)

        cy.get('li').contains(testPort1).closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').click()
        cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Promote a leader').click()
        cy.get('span:contains(Failover) + span:contains(Leader promotion successful)').click()
        checkIconColor(greenIcon, testPort1)
    })
})
