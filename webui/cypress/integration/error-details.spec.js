

/// <reference types="cypress" />

describe('Error details', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
        cleanup()
        fio = require('fio')
        helpers = require('test.helper')

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

        _G.cluster:start()
        return _G.cluster.datadir
      `
    })
  });

  after(() => {
    cy.task('tarantool', {code: `cleanup()`});
  });

  it('Open WebUI', () => {
    cy.visit('/admin/cluster/dashboard')
  });

  function checksForErrorDetails(){
    cy.contains('Invalid cluster topology config');
    cy.get('div').contains('stack traceback:');

    cy.get('button[type="button"]:contains(Copy details)').trigger('mouseover');
    cy.get('div').contains('Copy to clipboard');

    cy.get('button[type="button"]:contains(Copy details)').click();
    cy.get('div').contains('Copied');
    cy.get('div').contains('Copy to clipboard');

    cy.get('button[type="button"]').contains('Close').click();
    cy.contains('Invalid cluster topology config').should('not.exist');
  }

  it('Error details in notification', () => {
    cy.get('li').contains('test-replicaset').closest('li').find('.meta-test__ReplicasetServerListItem__dropdownBtn').eq(0).click();
    cy.get('.meta-test__ReplicasetServerListItem__dropdown *').contains('Expel server').click();
    cy.get('.meta-test__ExpelServerModal button[type="button"]').contains('Expel').click();
    cy.get('button[type="button"]:contains(Error details)').click();
    checksForErrorDetails();
  })

  it('Error details in notification list', () => {
    cy.get('button.meta-test__LoginBtn').parent('div').prev().click();
    cy.get('button[type="button"]:contains(Error details)').click();
    checksForErrorDetails();
  })

  it('Check Clear button in notification list', () => {
    cy.get('button.meta-test__LoginBtn').parent('div').prev().click();
    cy.get('button[type="button"]').contains('Clear').click();

    cy.get('button.meta-test__LoginBtn').parent('div').prev().click();
    cy.get('span').contains('No notifications');
  })
})
