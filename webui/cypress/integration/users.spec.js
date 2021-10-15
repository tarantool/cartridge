describe('Users', () => {
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
        env = {TARANTOOL_APP_NAME = 'cartridge-testing'},
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
      _G.cluster.main_server.net_box:call(
        'package.loaded.cartridge.failover_set_params',
        {{failover_timeout = 0}}
      )
      return _G.cluster.datadir
    `,
    });
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  it('Test: users', () => {
    ////////////////////////////////////////////////////////////////////
    cy.log('Tab title on Users page');
    ////////////////////////////////////////////////////////////////////
    cy.visit('/admin/cluster/dashboard');
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.testScreenshots('UsersPage');
    cy.title().should('eq', 'cartridge-testing.r1: Users');

    ////////////////////////////////////////////////////////////////////
    cy.log('Users page before changing');
    ////////////////////////////////////////////////////////////////////
    cy.get('h1:contains(Users)');
    cy.get('.meta-test__AuthToggle input').should('not.be.checked');
    cy.get('button:contains(Add user)').should('be.enabled');

    cy.get('thead th').each((tHeadRow, index) => {
      const headings = ['Username', 'Full name', 'E-mail', 'Actions'];
      cy.wrap(tHeadRow).should('contain', headings[index]);
    });

    cy.get('tbody td').eq(0).find('a:contains(admin)');
    cy.get('tbody td').eq(1).contains('Cartridge Administrator');
    cy.get('tbody td').eq(2).contains('—');
    cy.get('tbody td').eq(3).find('button').eq(0).should('be.disabled');
    cy.get('tbody td').eq(3).find('button').eq(1).should('be.disabled');

    ////////////////////////////////////////////////////////////////////
    cy.log('Checks for add user form fields');
    ////////////////////////////////////////////////////////////////////
    cy.get('button:contains(Add user)').click();
    cy.get('h2:contains(Add a new user)');
    cy.get('label:contains(Username)').parent('div').next().find('input').should('be.focused');
    cy.focused().blur();
    cy.testElementScreenshots('LoginSplash', 'form.meta-test__UserAddForm');
    cy.get('label:contains(Username)').parent('div').next().find('input').focus();

    //Add user form before changing
    cy.get('label:contains(Username)').parent('div').next().find('input').should('have.value', '');
    cy.get('label:contains(Password)').parent('div').next().find('input').should('have.value', '');
    cy.get('label:contains(Email)').parent('div').next().find('input').should('have.value', '');
    cy.get('label:contains(Full name)').parent('div').next().find('input').should('have.value', '');

    //Checks for compliance
    cy.get('.meta-test__UserAddForm button:contains(Add)').click();
    cy.get('label:contains(Username)').parent('div').next().next().contains('username is a required field');
    cy.get('label:contains(Password)').parent('div').next().next().contains('password is a required field');

    //Validation errors
    cy.get('label:contains(Email)').parent('div').next().find('input').type('q');
    cy.get('label:contains(Email)').parent('div').next().next().contains('email must be a valid email');

    //close modal without saving
    cy.get('h2:contains(Add a new user)').next().click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Add new user: success');
    ////////////////////////////////////////////////////////////////////
    cy.get('button:contains(Add user)').click();
    cy.get('h2:contains(Add a new user)');

    cy.get('label:contains(Username)').parent('div').next().find('input').type('TestUserName');
    cy.get('label:contains(Password)').parent('div').next().find('input').type('userpassword');
    cy.get('label:contains(Email)').parent('div').next().find('input').type('testuser@qq.qq');

    cy.get('.meta-test__UserAddForm button:contains(Add)').click();
    cy.get('tbody tr[role="row"]').should('have.length', 2);

    //checks for new user in list:
    cy.get('a:contains(TestUserName)')
      .parents('tr')
      .then((TestUserRow) => {
        cy.wrap(TestUserRow).find('td').eq(0).find('a:contains(TestUserName)');
        cy.wrap(TestUserRow).find('td').eq(2).contains('testuser@qq.qq');
        cy.wrap(TestUserRow).find('td').eq(3).find('button').eq(0).should('be.enabled');
        cy.wrap(TestUserRow).find('td').eq(3).find('button').eq(1).should('be.enabled');
      });

    ////////////////////////////////////////////////////////////////////
    cy.log('Click on user name -> opening modal Edit user');
    ////////////////////////////////////////////////////////////////////
    cy.get('a:contains(TestUserName)').click();
    cy.get('h2:contains(Edit TestUserName)').next().click();
    cy.get('h2:contains(Edit TestUserName)').should('not.exist');

    ////////////////////////////////////////////////////////////////////
    cy.log('Login and logout user without full name');
    ////////////////////////////////////////////////////////////////////

    //login:
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').should('be.focused');
    cy.focused().blur();
    cy.testElementScreenshots('LoginForm', 'div.meta-test__LoginForm');
    cy.get('.meta-test__LoginForm input[name="username"]').focus();
    cy.get('.meta-test__LoginForm input[name="username"]').type('TestUserName');
    cy.get('.meta-test__LoginForm input[name="password"]').type('userpassword');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LogoutBtn').children('span').should('contain', '');
    cy.get('.meta-test__LoginBtn').should('not.exist');

    //User cant delete himself
    cy.get('a:contains(TestUserName)').parents('tr').find('td').eq(3).find('button').eq(1).click();
    cy.get('.meta-test__UserRemoveModal button:contains(Remove)').click();
    cy.testElementScreenshots('UserRemoveModal', 'div.meta-test__UserRemoveModal');
    cy.get('span:contains(user can not remove himself)');
    cy.get('.meta-test__UserRemoveModal button:contains(Cancel)').click();

    //logout:
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Edit user');
    ////////////////////////////////////////////////////////////////////
    cy.get('a:contains(TestUserName)').parents('tr').find('td').eq(3).find('button').eq(0).click();
    cy.get('h2:contains(Edit TestUserName)');
    cy.get('label:contains(New password)').parent('div').next().find('input').should('be.focused');
    cy.focused().blur();
    cy.testElementScreenshots('EditUserForm', 'form.meta-test__UserEditModal');
    cy.get('label:contains(New password)').parent('div').next().find('input').focus();
    cy.get('label:contains(New password)').parent('div').next().find('input').type('{selectall}{del}EditedPassword');
    cy.get('label:contains(Email)').parent('div').next().find('input').type('{selectall}{del}ee@ee.ee');
    cy.get('label:contains(Full name)').parent('div').next().find('input').type('{selectall}{del}Edited Full Name');
    cy.get('button:contains(Save)').click();

    cy.get('a:contains(TestUserName)')
      .parents('tr')
      .then((TestUserRow) => {
        cy.wrap(TestUserRow).find('td').eq(1).contains('Edited Full Name');
        cy.wrap(TestUserRow).find('td').eq(2).contains('ee@ee.ee');
        cy.wrap(TestUserRow).find('td').eq(3).find('button').eq(0).should('be.enabled');
        cy.wrap(TestUserRow).find('td').eq(3).find('button').eq(1).should('be.enabled');
      });

    ////////////////////////////////////////////////////////////////////
    cy.log('Create user: errors');
    ////////////////////////////////////////////////////////////////////
    cy.get('button:contains(Add user)').click();
    cy.get('h2:contains(Add a new user)');

    cy.get('label:contains(Username)').parent('div').next().find('input').type('TestUserName');
    cy.get('label:contains(Password)').parent('div').next().find('input').type('userpassword');
    cy.get('label:contains(Email)').parent('div').next().find('input').type('ee@ee.ee');

    cy.get('.meta-test__UserAddForm button:contains(Add)').click();

    cy.get('.meta-test__UserAddForm').find("span:contains(User already exists: 'TestUserName')");
    cy.get('label:contains(Username)').parent('div').next().find('input').type('{selectall}{del}NewUserName');
    cy.get('.meta-test__UserAddForm button:contains(Add)').click();

    cy.get('.meta-test__UserAddForm').find("span:contains(E-mail already in use: 'ee@ee.ee')");
    cy.get('label:contains(Email)').parent('div').next().find('input').type('{selectall}{del}new@qq.qq');
    cy.get('.meta-test__UserAddForm button:contains(Add)').click();

    cy.get('tbody tr[role="row"]').should('have.length', 3);

    ////////////////////////////////////////////////////////////////////
    cy.log('Login and logout user with full name');
    ////////////////////////////////////////////////////////////////////

    //login:
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('TestUserName');
    cy.get('.meta-test__LoginForm input[name="password"]').type('EditedPassword');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LogoutBtn').children('span').should('contain', 'Edited Full Name');
    cy.get('.meta-test__LoginBtn').should('not.exist');

    //logout:
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();

    ////////////////////////////////////////////////////////////////////
    cy.log('Remove user');
    ////////////////////////////////////////////////////////////////////
    cy.get('a:contains(TestUserName)').parents('tr').find('td').eq(3).find('button').eq(1).click();
    cy.get('.meta-test__UserRemoveModal h2:contains(Please confirm)');
    cy.get('.meta-test__UserRemoveModal span:contains(Removing user TestUserName)');
    cy.get('.meta-test__UserRemoveModal button:contains(Remove)').click();

    cy.get('.meta-test__UserRemoveModal').should('not.exist');
    cy.contains('TestUserName').should('not.exist');
  });
});
