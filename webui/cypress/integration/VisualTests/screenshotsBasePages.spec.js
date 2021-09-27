describe('Screenshots', () => {
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
  });

  after(() => {
    cy.task('tarantool', { code: `cleanup()` });
  });

  const pages = ['cluster/dashboard', 'cluster/users', 'cluster/configuration', 'cluster/code'];
  const indicator = [
    '.meta-test__ProbeServerBtn',
    '.meta-test__addUserBtn',
    '.meta-test__DownloadBtn',
    '.meta-test__Code__FileTree',
  ];
  const sizes = ['macbook-15', 'macbook-13'];

  const prepareTest = (page, size) => {
    cy.visit('/admin/' + page);
    cy.viewport(size);
    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(1000);
  };

  let testOs = Cypress.platform.toString();
  let headlessMode = Cypress.browser.isHeadless;
  let mode;
  if (headlessMode) {
    mode = 'Headless';
  } else {
    mode = 'Window';
  }

  sizes.forEach((size) => {
    let i = 0;
    pages.forEach((page) => {
      it(`Should match previous screenshot '${page} Page' When '${size}' resolution in Os: ${testOs} mode is ${mode}`, () => {
        prepareTest(page, size);
        cy.get(indicator[i]);
        if (i == 3) {
          //just this element is in need of bluring
          cy.focused().blur();
        }
        // eslint-disable-next-line cypress/no-unnecessary-waiting
        cy.wait(1000);
        i++;
        cy.matchImageSnapshot();
      });
    });
  });
});
