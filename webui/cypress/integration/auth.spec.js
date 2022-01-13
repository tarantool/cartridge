describe('Auth', () => {
  beforeEach(() => {
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
    `,
    }).should('deep.eq', [true]);
  });

  afterEach(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  const email = 'testUser@mail.ru';
  const password = '12345678_Ujl';
  const username = 'testUser';
  const fullname = '';

  function addUserWithAPI(username, fullname, email, password) {
    cy.request({
      method: 'POST',
      url: 'http://localhost:8080/admin/api',
      headers: {
        'Content-Type': 'application/json',
        schema: 'admin',
      },
      body: {
        variables: { email: email, fullname: fullname, password: password, username: username },
        query: `
           mutation addUser($username: String!, $password: String!, $email: String!, $fullname: String!) {
                 cluster {
                    add_user(
                      username: $username
                      password: $password
                      email: $email
                      fullname: $fullname
                      )
                   {
                      username
                      email
                      fullname
                  }
                 }
           }
          `,
      },
    });
  }

  function editUserWithAPI(username, fullname, email, password) {
    cy.request({
      method: 'POST',
      url: 'http://localhost:8080/admin/api',
      headers: {
        'Content-Type': 'application/json',
        schema: 'admin',
      },
      body: {
        variables: { email: email, fullname: fullname, password: password, username: username },
        query: `
           mutation editUser($username: String!, $password: String, $email: String, $fullname: String) {
                 cluster {
                    edit_user(
                      username: $username
                      password: $password
                      email: $email
                      fullname: $fullname
                      )
                   {
                      username
                      email
                      fullname
                  }
                 }
           }
          `,
      },
    });
    cy.reload();
  }

  it('Test: auth 1', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__ProbeServerBtn').should('exist');
    cy.get('.meta-test__AuthToggle').should('not.exist');

    ///////////////////////////////////////////////////////////////////
    cy.log('Login window close by ESC');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm').type('{esc}').should('not.exist');

    ///////////////////////////////////////////////////////////////////
    cy.log('Login empty username and login');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').should('have.value', '');
    cy.get('.meta-test__LoginForm input[name="password"]').should('have.value', '');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('username is a required field');
    cy.get('.meta-test__LoginForm').contains('password is a required field');
    cy.get('.meta-test__LoginForm button[type="button"]').contains('Cancel').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Login empty username');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').should('have.value', '');
    cy.get('.meta-test__LoginForm input[name="password"]').type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('username is a required field');
    cy.get('.meta-test__LoginForm button[type="button"]').contains('Cancel').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Login empty pw');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('admin').should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]').should('have.value', '');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('password is a required field');
    cy.get('.meta-test__LoginForm button[type="button"]').contains('Cancel').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Login error');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('error').should('have.value', 'error');
    cy.get('.meta-test__LoginForm input[name="password"]').type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('Authentication failed');
    cy.get('.meta-test__LoginForm button[type="button"]').contains('Cancel').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Login password wrong');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('admin').should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]').type('incorrect password');
    cy.get('.meta-test__LoginFormBtn').click();
    cy.get('.meta-test__LoginForm').contains('Authentication failed');
    //check button X in the auth form
    cy.get('.meta-test__LoginForm > svg').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Login and Enable Auth');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();

    cy.get('.meta-test__LoginForm input[name="username"]').type('admin').should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]').type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();

    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(100); // wait for a react re-render.

    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__AuthToggle input').should('not.be.checked');
    cy.get('.meta-test__AuthToggle').click();
    cy.get('.meta-test__ConfirmModal').contains('Enable').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Logout');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Login and Disable auth');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginFormSplash').should('exist');

    cy.get('input[name="username"]').type('admin');
    cy.get('input[name="password"]').type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__AuthToggle input').should('be.checked');
    cy.get('.meta-test__AuthToggle').click();
    cy.get('.meta-test__ConfirmModal').contains('Disable').click();
    cy.get('.meta-test__AuthToggle input').should('not.be.checked');

    ////////////////////////////////////////////////////////////////////
    cy.log('Disabled users page usecase');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', {
      code: `
      _G.cluster.main_server:stop()
      _G.cluster.main_server.command = helpers.entrypoint('srv_woauth')
      _G.cluster.main_server:start()
      return true
    `,
    }).should('deep.eq', [true]);
    cy.get('a[href="/admin/cluster/dashboard"]').click();
    cy.reload();

    cy.get('.meta-test__AuthToggle').should('exist');
    cy.get('a[href="/admin/cluster/users"]').should('not.exist');
  });

  it('Test: auth 2', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Open WebUI');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');

    ////////////////////////////////////////////////////////////////////
    cy.log('Login successfully');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LoginBtn').click();

    cy.get('.meta-test__LoginForm input[name="username"]').type('admin').should('have.value', 'admin');
    cy.get('.meta-test__LoginForm input[name="password"]').type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();

    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(100); // wait for a react re-render.

    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__AuthToggle input').should('not.be.checked');

    ////////////////////////////////////////////////////////////////////
    cy.log('Enable auth');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__AuthToggle').click();
    cy.get('.meta-test__ConfirmModal').contains('Enable').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Logout');
    ////////////////////////////////////////////////////////////////////
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown').click();
    ////////////////////////////////////////////////////////////////////
    cy.log('Shut down cluster');
    ////////////////////////////////////////////////////////////////////
    cy.task('tarantool', {
      code: `
      _G.cluster:stop()
      return true
    `,
    }).should('deep.eq', [true]);

    ////////////////////////////////////////////////////////////////////
    cy.log('Try to log on');
    ////////////////////////////////////////////////////////////////////

    cy.get('input[name="username"]').type('admin').should('have.value', 'admin');
    cy.get('input[name="password"]').type('test-cluster-cookie');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LoginFormSplash form').contains('Cannot connect to server. Please try again later.');
  });

  it('Test: check fullname is empty and username is displaying when authorized', () => {
    cy.log('Add user with API');
    addUserWithAPI(username, fullname, email, password);

    cy.log('Login with API created user with empty full');
    cy.visit('/admin/cluster/dashboard');
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('testUser');
    cy.get('.meta-test__LoginForm input[name="password"]').type('12345678_Ujl');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.log('Check there is username in the right top corner for the authorized user: fullname is empty');
    cy.get('.meta-test__LogoutBtn span').contains(username);

    const notEmptyFullname = 'testUserFullname';
    editUserWithAPI(username, notEmptyFullname, email, password);

    cy.log('Check there is fullname in the right top corner for the authorized user: fullname is not empty');
    cy.get('.meta-test__LogoutBtn span').contains(notEmptyFullname);

    editUserWithAPI(username, fullname, email, password);

    cy.log('Check there is username in the right top corner for the authorized user: fullname is empty');
    cy.get('.meta-test__LogoutBtn span').contains(username);
  });
});
