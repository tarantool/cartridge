describe('Uninitialized', () => {

  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.server = helpers.Server:new({
        alias = 'spare',
        workdir = fio.tempdir(),
        command = helpers.entrypoint('srv_basic'),
        replicaset_uuid = helpers.uuid('с'),
        http_port = 8080,
        advertise_port = 13300,
        cluster_cookie = helpers.random_cookie(),
      })
      _G.server:start()
      helpers.retrying({timeout = 5}, function()
        _G.server:graphql({query = '{ servers { uri } }'})
      end)
      return true
    `
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: uninitialized', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Code without bootstrap');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/code');
    // files reload should fail
    cy.get('button[type="button"]:contains("Reload")').click();
    cy.get('body').contains('Are you sure you want to reload all the files?');
    cy.get('button[type="button"]:contains("Ok")').click();
    cy.get('span:contains("Current instance isn\'t bootstrapped yet") + button + svg').click();

    // create file
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree\n');
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree');

    // file upload should fail too
    cy.get('button[type="button"]:contains("Apply")').click();
    cy.get('span:contains("Current instance isn\'t bootstrapped yet") + button + svg').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Schema without bootstrap');
    ////////////////////////////////////////////////////////////////////
    cy.get('a[href="/admin/cluster/schema"]').click();

    cy.get('button[type="button"]:contains("Validate")').click();
    cy.get('#root').contains('Current instance isn\'t bootstrapped yet');

    cy.get('button[type="button"]:contains("Reload")').click();
    cy.get('.monaco-editor textarea').should('have.value', '');

    cy.get('button[type="button"]:contains("Apply")').click();
    cy.get('#root').contains('Current instance isn\'t bootstrapped yet');

    ////////////////////////////////////////////////////////////////////
    cy.log('Try to add user without bootstrap');
    ////////////////////////////////////////////////////////////////////
    cy.get('a[href="/admin/cluster/users"]').click();

    cy.get('.meta-test__addUserBtn').click({ force: true });
    cy.get('label:contains(Username)').parent('div').next().find('input')
      .type('unitialisedUser');
    cy.get('label:contains(Password)').parent('div').next().find('input')
      .type('111');
    cy.get('.meta-test__UserAddForm button[type="submit"]').contains('Add').click();
    cy.get('.meta-test__UserAddForm')
      .contains('Current instance isn\'t bootstrapped yet');
    cy.get('.meta-test__UserAddForm button[type="button"]').contains('Cancel').click();
    cy.contains('unitialisedUser').should('not.exist');
  });
});
