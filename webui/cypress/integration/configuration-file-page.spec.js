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
    `}).should('deep.eq', [true]);
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
        const filepath = 'files/config.yml';
        cy.get('input[type="file"]').attachFile(filepath);
        cy.get('[data-cy="test_uploadZone"]').contains('New configuration uploaded successfully.');
        cy.get('[data-cy="test_uploadZone"]').contains('config.yml');
  });

    it('Test: unsuccessful upload config file', () => {

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
        cy.log('Upload conf file not in yml format');
        ////////////////////////////////////////////////////////////////////
        const filepath = 'files/config.zip';
        cy.get('input[type="file"]').attachFile(filepath);
        cy.get('[data-cy="test_uploadZone"]').contains('DecodeYamlError: control characters are not allowed at document: 0');
    });
});
