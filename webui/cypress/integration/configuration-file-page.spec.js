describe('Configuration file page', () => {

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
          alias = 'test-replicaset',
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

  it('Test: successfull upload config file', () => {

    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/configuration');
    cy.get('.test__Header').contains('/Configuration files');
    cy.get('[data-cy="test_uploadZone"]').contains('Upload configuration');
    cy.get('[data-cy="test_uploadZone"]').contains('New configuration can be uploaded here.');
    cy.get('[data-cy="test_uploadZone"]').contains('Click or drag file to this area to upload');
    cy.get('.meta-test__DownloadBtn').should('exist');

    ///////////////////////////////////////////////////////////////////
    cy.log('Upload conf file');
    ////////////////////////////////////////////////////////////////////
    cy.get('input[type="file"]').attachFile('files/config.good.yml');
    cy.get('[data-cy="test_uploadZone"]').contains('New configuration uploaded successfully.');
    cy.get('[data-cy="test_uploadZone"]').contains('config.good.yml');

    ///////////////////////////////////////////////////////////////////
    cy.log('Upload incorrect yml conf file');
    ////////////////////////////////////////////////////////////////////
    cy.get('input[type="file"]').attachFile('files/config.bad.yml');
    cy.get('[data-cy="test_uploadZone"]').contains('Config upload failed: uploading system section ' +
      '"topology" is forbidden');

    ///////////////////////////////////////////////////////////////////
    cy.log('Download current conf file');
    ////////////////////////////////////////////////////////////////////
    cy.downloadFile('/admin/config', 'cypress/fixtures/Download', 'config_downloaded.yml')
    //cy.readFile('cypress/fixtures/Download/test.txt').should('contain', 'Lorem ipsum dolor sit amet')
  });
});
