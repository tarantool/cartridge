describe('Code page', () => {
  before(() => {
    cy.task('tarantool', {
      code: `
      cleanup()

      _G.cluster = helpers.Cluster:new({
        datadir = fio.tempdir(),
        server_command = helpers.entrypoint('srv_basic'),
        use_vshard = true,
        cookie = helpers.random_cookie(),
        replicasets = {{
          uuid = helpers.uuid('a'),
          alias = 'dummy',
          roles = {'vshard-router', 'vshard-storage', 'failover-coordinator'},
          servers = {{http_port = 8080}, {}},
        }}
      })

      for _, srv in pairs(_G.cluster.servers) do
        srv.env.TARANTOOL_INSTANCE_NAME = srv.alias
        srv.env.TARANTOOL_WEBUI_PREFIX = '/' --[[ should be ignored ]]
      end
      _G.cluster:start()
      return true
    `,
    }).should('deep.eq', [true]);
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  const selectAllKeys = Cypress.platform === 'darwin' ? '{cmd}a' : '{ctrl}a';

  function reload() {
    cy.get('.meta-test__Code__reload_idle').click({ force: true });
    cy.get('button[type="button"]').contains('Ok').click();
    cy.get('.meta-test__Code__reload_loading').should('not.exist');
    cy.get('.meta-test__Code__reload_idle').should('exist');
  }
  function apply() {
    cy.get('.meta-test__Code__apply_idle').click({ force: true });
    cy.get('.meta-test__Code__apply_loading').should('not.exist');
    cy.get('.meta-test__Code__apply_idle').should('exist');
  }

  it('Test: open-code-page', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/code');
    cy.get('.meta-test__Code__apply_idle').should('exist');
    cy.title().should('eq', 'dummy-1: Code');

    ////////////////////////////////////////////////////////////////////
    cy.log('Empty code page');
    ////////////////////////////////////////////////////////////////////
    cy.get('#root').contains('Please select a file');
    cy.get('button[type="button"]').contains('Apply').click();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();
  });

  it('Test: schema', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('File in tree');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('schema.yml');
    cy.get('#root').contains('dummy-1').click();
    cy.get('.meta-test__Code__FileTree').contains('schema.yml').click();

    // Type incorrect
    cy.get('.monaco-editor').click();
    cy.focused().type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor').type('spaces: incorrect-1');
    cy.get('.monaco-editor').contains('spaces: incorrect-1');
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('spaces: must be a table, got string').should('exist').click();

    // Type correct
    cy.get('.monaco-editor').click();
    cy.focused().type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor').type('spaces: [] # Essentially the same');
    cy.get('button[type="button"]').contains('Validate').click();
    cy.get('#root').contains('The code is valid').should('exist').click();
  });

  it('Test: code-page', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('File in tree');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree1.yml');
    cy.get('#root').contains('dummy-1').click();
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree1.yml');

    //file with the same name is not created
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree1.yml');
    cy.get('.meta-test__enterName').focused().type('{enter}');
    cy.get('div:contains(The name already exists)').should('not.exist');
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree1.yml');
    //error when file with the same name already exists
    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree1.yml');
    cy.get('div:contains(The name already exists)');
    cy.get('.meta-test__enterName').focused().type('1');
    cy.get('div:contains(The name already exists)').should('not.exist');
    //error when folder with the same name already exists
    cy.get('.meta-test__addFolderBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree1.yml');
    cy.get('div:contains(The name already exists)');

    reload();
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree1.yml').should('not.exist');

    cy.get('.meta-test__addFileBtn').click();
    cy.get('.meta-test__enterName').focused().type('file-in-tree2.yml{enter}');
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree2.yml');

    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    cy.get('.meta-test__Code__FileTree').contains('file-in-tree2.yml');
    reload();
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree2.yml');

    //file contents
    cy.get('.meta-test__Code__FileTree').contains('file-in-tree2.yml').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('some test code');

    //check for page change
    cy.get('a[href="/admin/cluster/dashboard"]').click();
    cy.get('h1:contains(Cluster)');
    cy.get('a[href="/admin/cluster/code"]').click();
    cy.get('h1:contains(Code)');
    cy.get('.monaco-editor textarea').should('have.value', 'some test code');

    reload();
    cy.get('.monaco-editor textarea').should('have.value', '');

    cy.get('.meta-test__Code__FileTree').contains('file-in-tree2.yml').click();
    cy.get('.monaco-editor textarea').type('some test code2');

    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    reload();
    cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

    //wrong yaml error
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('some: [] test code2');
    apply();
    cy.get('#root')
      .contains(
        'LoadConfigError: Error parsing section "file-in-tree2.yml":' + ' did not find expected key at document'
      )
      .click();
    reload();
    cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

    //edit file and file contents
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-file-name{enter}');
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name');

    //reload
    reload();
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name').should('not.exist');

    //apply
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-file-name2{enter}');
    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    reload();
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').click();

    //file contents
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('edit test code');
    cy.get('.monaco-editor textarea').should('have.value', 'edit test code');

    reload();
    cy.get('.monaco-editor textarea').should('have.value', 'some test code2');

    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('edit test code2');

    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    reload();
    cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');

    //delete file and file contents
    //file contents
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');
    cy.get('.monaco-editor textarea').type('a{backspace}'); //без этого не работает
    cy.get('.monaco-editor textarea').should('have.value', '');

    reload();
    cy.get('.monaco-editor textarea').should('have.value', 'edit test code2');

    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').click();
    cy.get('.monaco-editor textarea').type(selectAllKeys + '{backspace}');

    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    reload();
    cy.get('.monaco-editor textarea').should('have.value', '');

    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').should('not.exist');

    reload();
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2');

    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal').should('be.visible');
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();

    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    reload();
    cy.get('.meta-test__Code__FileTree').contains('edited-file-name2').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Folder in tree');
    ////////////////////////////////////////////////////////////////////

    //create folder
    cy.get('.meta-test__addFolderBtn').click();
    cy.get('.meta-test__enterName').focused().type('folder-in-tree');
    cy.get('#root').contains('dummy-1').click();
    cy.get('.meta-test__Code__FileTree').contains('folder-in-tree');

    //create folder in folder
    cy.get('.meta-test__createFolderInTreeBtn').click({ force: true });
    cy.get('.meta-test__enterName').focused().type('folder-in-folder{enter}');
    cy.get('.meta-test__Code__FileTree').contains('folder-in-folder');

    //create file in folder
    cy.get('.meta-test__createFileInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().type('file-in-folder{enter}');
    cy.get('.meta-test__Code__FileTree').contains('file-in-folder').click({ force: true });
    cy.get('.meta-test__Code').contains('folder-in-tree / file-in-folder');
    cy.get('.monaco-editor textarea').type('new test code');

    //edit folder name
    cy.get('.meta-test__editFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__enterName').focused().clear().type('edited-folder-name{enter}');
    cy.get('.meta-test__Code__FileTree').contains('edited-folder-name');
    cy.get('.meta-test__Code__FileTree').contains('file-in-folder').should('be.visible');

    //save changes and full reload code page
    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    cy.reload();
    cy.contains('Not loaded').should('not.exist');
    cy.get('.meta-test__Code__FileTree').contains('folder-in-folder').should('not.exist');
    cy.get('.meta-test__Code__FileTree').contains('file-in-folder').should('exist').click();
    cy.get('.meta-test__Code').contains('edited-folder-name / file-in-folder');
    cy.get('.monaco-editor textarea').should('have.value', 'new test code');

    //delete folder
    cy.get('.meta-test__deleteFolderInTreeBtn').eq(0).click({ force: true });
    cy.get('.meta-test__deleteModal').should('be.visible');
    cy.get('.meta-test__deleteModal button[type="button"]').contains('Ok').click();

    apply();
    cy.get('span:contains(Success) + span:contains(Files successfuly applied) + svg').click();

    cy.get('.meta-test__Code__FileTree').contains('edited-folder-name').should('not.exist');
  });
});
