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

    const filterValue = new Map([
      [1, 'Healthy'],
      [2, 'Unhealthy'],
      [3, 'failover-coordinator'],
      [4, 'vshard-storage'],
      [5, 'vshard-router'],
      [6, 'myrole-dependency'],
      [7, 'myrole'],
    ]);

    const filteredValue = new Map([
      [1, 'status:healthy'],
      [2, 'status:unhealthy'],
      [3, 'role:failover-coordinator'],
      [4, 'role:vshard-storage'],
      [5, 'role:vshard-router'],
      [6, 'role:myrole-dependency'],
      [7, 'role:myrole'],
    ]);

    for (let i = 1; i <= 7; i++) {
      it(`Check ${filterValue.get(i)} ${filteredValue.get(i)} `, () => {
        cy.get('button[type="button"]:contains(Filter)').click();
        cy.get('.meta-test__Filter__Dropdown *').contains(new RegExp('^' + filterValue.get(i) + '$'))
          .click({ force: true });
        cy.get('.meta-test__Filter input').should('have.value', `${filteredValue.get(i)}`);
        cy.reload(true);
        cy.get('.meta-test__Filter input').should('have.value', `${filteredValue.get(i)}`);
      });
    }
  });
});
