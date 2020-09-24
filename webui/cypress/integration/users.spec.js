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

  it('Tab title on Users page', () => {
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.title().should('eq', 'cartridge-testing.r1: Users')
  })

  it('Add user', () => {
    cy.get('.meta-test__addUserBtn').click();

    //Required field checks on Add user form
    cy.get('.meta-test__UserAddForm button[type="submit"]').contains('Add').click();
    cy.get('label:contains(username)').nextAll('div:contains(username is a required field)');
    cy.get('label:contains(password)').nextAll('div:contains(password is a required field)');

    cy.get('.meta-test__UserAddForm input[name="username"]').type('user_do_not_touch')
      .should('have.value', 'user_do_not_touch');
    cy.get('.meta-test__UserAddForm input[name="password"]').type('123');

    //Try to enter invalid email on Add user form
    cy.get('.meta-test__UserAddForm input[name="email"]').type('not_valid');
    cy.get('.meta-test__UserAddForm input[name="username"]').focus();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email');
    cy.get('.meta-test__UserAddForm input[name="email"]').type('{selectall}{backspace}').blur();
    cy.get('.meta-test__UserAddForm').contains('email must be a valid email').should('not.exist');
    
    cy.get('.meta-test__UserAddForm button[type="submit"]').contains('Add').click();
    cy.get('.meta-test__UsersTable').contains('user_do_not_touch');
  })

  it('Login and logout user without full name', () => {
    //login:
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('user_do_not_touch');
    cy.get('.meta-test__LoginForm input[name="password"]').type('123');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LogoutBtn').children('span').should('contain', '');
    cy.get('.meta-test__LoginBtn').should('not.exist');

    // //User cant delete himself
    // cy.get('.meta-test__UsersTable li:contains(user_do_not_touch)').find('button').click();
    // cy.get('.meta-test__UsersTableItem__dropdown *').contains('Remove user').click();
    // cy.get('.meta-test__UserRemoveModal button[type="button"]:contains(Remove)').click();
    // cy.get('span:contains(user can not remove himself)').click(); //bug: error doesnt show

    //logout:
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();
  })

  it('Edit user', () => {
    cy.get('.meta-test__UsersTable').find('button').eq(1).click();
    cy.get('.meta-test__UsersTableItem__dropdown *').contains('Edit user').click();
    cy.get('.meta-test__UserEditModal h2').contains('Edit user_do_not_touch');

    cy.get('.meta-test__UserEditModal input[name="password"]').type('{selectall}{del}321');

    //Try to enter invalid email on Edit user form
    cy.get('.meta-test__UserEditModal input[name="email"]').type('not_valid');
    cy.get('.meta-test__UserEditModal button[type="submit"]').contains('Save').click();
    cy.get('label:contains(email)').nextAll('div:contains(email must be a valid email)');
    cy.get('.meta-test__UserEditModal input[name="email"]').type('{selectall}{backspace}').blur();
    cy.get('.meta-test__UserEditModal').contains('email must be a valid email').should('not.exist');
    
    cy.get('.meta-test__UserEditModal input[name="email"]')
      .type('donottouch@qq.qq')
      .should('have.value', 'donottouch@qq.qq');
    cy.get('.meta-test__UserEditModal input[name="fullname"]')
      .type('Full Name donottouch')
      .should('have.value', 'Full Name donottouch');
    cy.get('.meta-test__UserEditModal button[type="submit"]').contains('Save').click();
    cy.get('.meta-test__UsersTable').contains('Full Name donottouch');
  })

  it('Login and logout user with full name', () => {
    //login:
    cy.get('.meta-test__LoginBtn').click();
    cy.get('.meta-test__LoginForm input[name="username"]').type('user_do_not_touch');
    cy.get('.meta-test__LoginForm input[name="password"]').type('321');
    cy.get('.meta-test__LoginFormBtn').click();

    cy.get('.meta-test__LogoutBtn').children('span').should('contain', 'Full Name donottouch');
    cy.get('.meta-test__LoginBtn').should('not.exist');

    //logout:
    cy.get('.meta-test__LogoutBtn').click();
    cy.get('.meta-test__LogoutDropdown *').contains('Log out').click();
  })

  it('Remove user', () => {
    cy.get('.meta-test__UsersTable li:contains(user_do_not_touch)').find('button').click();
    cy.get('.meta-test__UsersTableItem__dropdown *').contains('Remove user').click();
    cy.get('.meta-test__UserRemoveModal button[type="button"]:contains(Remove)').click();

    cy.get('.meta-test__UsersTable').contains('user_do_not_touch').should('not.exist');
  })

});
