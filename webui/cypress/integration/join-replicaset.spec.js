describe('Join Replica Set', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()
        local workdir = fio.tempdir()
        _G.cluster = helpers.Cluster:new({
          datadir = workdir,
          server_command = helpers.entrypoint('srv_basic'),
          use_vshard = true,
          cookie = 'test-cluster-cookie',
          env = {
              TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 0,
              TARANTOOL_APP_NAME = 'cartridge-testing',
          },
          replicasets = {{
            alias = 'test-replicaset',
            uuid = helpers.uuid('a'),
            roles = {'vshard-router', 'vshard-storage', 'failover-coordinator'},
            servers = {{
              alias = 'server1',
              env = {TARANTOOL_INSTANCE_NAME = 'r1'},
              instance_uuid = helpers.uuid('a', 'a', 1),
              advertise_port = 13300,
              http_port = 8080
            }}
          }}
        })

        _G.server = helpers.Server:new({
            workdir = workdir.."/spare",
            alias = 'spare',
            command = helpers.entrypoint('srv_basic'),
            replicaset_uuid = helpers.uuid('с'),
            instance_uuid = helpers.uuid('b', 'b', 3),
            http_port = 8081,
            cluster_cookie = _G.cluster.cookie,
            advertise_port = 13301,
            env = {TARANTOOL_SWIM_SUSPECT_TIMEOUT_SECONDS = 1},
        })
        _G.cluster:start()
        _G.server:start()
        return true
      `
    }).should('deep.eq', [true])
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard')
  });

  it('Join Replica Set', () => {
    cy.get('li').contains('localhost:13301').closest('li').find('button').contains('Configure').click({ force: true });
    cy.get('.meta-test__ConfigureServerModal').contains('Join Replica Set').click();
    cy.get('.meta-test__ConfigureServerModal input[name="replicasetUuid"]').eq(0).check({ force: true });
    cy.get('.meta-test__JoinReplicaSetBtn').click();
    cy.get('#root').contains('Join is OK. Please wait for list refresh...');
  })
});
