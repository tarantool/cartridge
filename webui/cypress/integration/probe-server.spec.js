describe('Probe server', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = false,
        cookie = 'test-cluster-cookie',
        replicasets = {{
          alias = 'a',
          roles = {},
          servers = {{http_port = 8080}},
        }}
      })

      _G.cluster:start()
      return true
    `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: probe-server', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Shows probing errors and close modal window with X button in it');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__ProbeServerBtn').click();
    cy.get('.ProbeServerModal input[name="uri"]')
      .should('be.focused')
      .should('have.attr', 'placeholder', 'Server URI, e.g. localhost:3301');
    cy.get('.ProbeServerModal input[name="uri"]').type('unreachable').should('have.value', 'unreachable');

    cy.get('.meta-test__ProbeServerSubmitBtn').click();

    cy.get('.ProbeServerModal_error').contains('Probe "unreachable" failed: ping was not sent');
    //check if X button  works correclty
    cy.get('.ProbeServerModal svg').click();
    cy.get('.ProbeServerModal').should('not.exist');

    //Try to enter empty and press Enter
    cy.get('.meta-test__ProbeServerBtn').click();
    cy.get('.ProbeServerModal input[name="uri"]')
      .should('be.focused')
      .should('have.attr', 'placeholder', 'Server URI, e.g. localhost:3301');
    cy.get('.ProbeServerModal input[name="uri"]').type('{selectall}{backspace}').type(' ');
    cy.get('.ProbeServerModal input[name="uri"]').type('{enter}');
    cy.get('.ProbeServerModal_error').contains('Probe " " failed: parse error');

    ////////////////////////////////////////////////////////////////////
    cy.log('Shows probings success message');
    ////////////////////////////////////////////////////////////////////
    cy.get('.ProbeServerModal input[name="uri"]').clear().type('localhost:13301');

    cy.get('.meta-test__ProbeServerSubmitBtn').click();

    cy.get('span:contains(Probe is OK. Please wait for list refresh...)').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Press Escape for close dialog');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__ProbeServerBtn').click();
    cy.get('.ProbeServerModal').type('{esc}').should('not.exist');
  });
});
