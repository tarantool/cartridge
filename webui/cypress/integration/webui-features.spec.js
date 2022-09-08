describe('Web UI features testing', () => {
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
    `,
    }).should('deep.eq', [true]);
    cy.clearLocalStorageSnapshot();
    cy.setLocalStorage('tt.menu_collapsed', '0');
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  describe('Test LeftMenu stage', () => {
    beforeEach(() => {
      cy.restoreLocalStorage();
      cy.visit('/admin/cluster/dashboard');
    });

    afterEach(() => {
      cy.saveLocalStorage();
    });

    function openLeftMenu() {
      cy.get('button').should('have.attr', 'title', 'Collapse menu').click();
    }

    function closeLeftMenu() {
      cy.get('button').should('have.attr', 'title', 'Collapse menu').click();
    }

    it('Test: left menu state is saving when page is reloaded', () => {
      ////////////////////////////////////////////////////////////////
      cy.setLocalStorage('tt.menu_collapsed', '0');
      cy.log('check left menu is not collappsed');
      ////////////////////////////////////////////////////////////////
      cy.getLocalStorage('tt.menu_collapsed').then(($isSideMenuClosed) => {
        expect($isSideMenuClosed).to.equal('0');
      });
      cy.contains('Collapse menu').should('exist');

      closeLeftMenu();

      ////////////////////////////////////////////////////////////////
      cy.log('check left menu is collappsed');
      ////////////////////////////////////////////////////////////////
      cy.contains('Collapse menu').should('not.exist');
      cy.getLocalStorage('tt.menu_collapsed').then(($isSideMenuClosed) => {
        expect($isSideMenuClosed).to.equal('1');
      });
      cy.reload(true);

      ////////////////////////////////////////////////////////////////
      cy.log('Check collapsed menu is saved when a page has been reloaded');
      ////////////////////////////////////////////////////////////////
      cy.getLocalStorage('tt.menu_collapsed').then(($isSideMenuClosed) => {
        expect($isSideMenuClosed).to.equal('1');
      });
      cy.contains('Collapse menu').should('not.exist');

      //open collapsed menu
      openLeftMenu();
      cy.reload(true);

      ////////////////////////////////////////////////////////////////
      cy.log('check left menu is not collappsed');
      ////////////////////////////////////////////////////////////////
      cy.getLocalStorage('tt.menu_collapsed').then(($isSideMenuClosed) => {
        expect($isSideMenuClosed).to.equal('0');
      });
      cy.contains('Collapse menu').should('exist');

      closeLeftMenu();
    });

    it('Test: left menu state is saving when page is reopened with collapsed menu', () => {
      ////////////////////////////////////////////////////////////////
      cy.log('check left menu collappsed');
      ////////////////////////////////////////////////////////////////
      cy.getLocalStorage('tt.menu_collapsed').then(($isSideMenuClosed) => {
        expect($isSideMenuClosed).to.equal('1');
      });
      cy.contains('Collapse menu').should('not.exist');

      openLeftMenu();
    });

    it('Test: left menu state is saving when page is reopened with not collapsed menu', () => {
      ////////////////////////////////////////////////////////////////
      cy.log('check left menu is not collappsed');
      ////////////////////////////////////////////////////////////////
      cy.getLocalStorage('tt.menu_collapsed').then(($isSideMenuClosed) => {
        expect($isSideMenuClosed).to.equal('0');
      });
      cy.contains('Collapse menu').should('exist');
    });
  });

  describe('Test filter stage on Cluster page after reload page', () => {
    beforeEach(() => {
      cy.restoreLocalStorage();
      cy.setLocalStorage('tt.menu_collapsed', '0');
      cy.visit('/admin/cluster/dashboard');
    });

    afterEach(() => {
      cy.saveLocalStorage();
    });

    const filterValues = [
      ['Healthy', 'status:healthy'],
      ['Unhealthy', 'status:unhealthy'],
      ['Leader', 'is:leader'],
      ['Follower', 'is:follower'],
      ['failover-coordinator', 'role:failover-coordinator'],
      ['vshard-storage', 'role:vshard-storage'],
      ['vshard-router', 'role:vshard-router'],
      ['myrole-dependency', 'role:myrole-dependency'],
      ['myrole', 'role:myrole'],
    ];

    filterValues.forEach(([label, value]) => {
      it(`Check ${label} ${value}`, () => {
        cy.get('.meta-test__Filter input').clear();
        cy.get('button[type="button"]:contains(Filter)').click();
        cy.get('.meta-test__Filter__Dropdown *')
          .contains(new RegExp(`^${label}$`))
          .click({ force: true });
        cy.get('.meta-test__Filter input').should('have.value', value);
        cy.reload(true);
        cy.get('.meta-test__Filter input').should('have.value', value);
      });
    });
  });
});
