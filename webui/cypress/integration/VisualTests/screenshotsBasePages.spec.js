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

  const pages = ['dashboard', 'users', 'configuration', 'code'];
  const indicator = [
    '.meta-test__ProbeServerBtn',
    '.meta-test__addUserBtn',
    '.meta-test__DownloadBtn',
    '.meta-test__Code__FileTree',
  ];
  const sizes = ['macbook-15', 'macbook-13', [1920, 1080]];

  const prepareTest = (page, size) => {
    cy.visit('/admin/cluster/' + page);
    cy.setResolution(size);
    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(1000);
  };

  const os = Cypress.platform.toString();
  let mode = Cypress.browser.isHeadless ? 'headless' : 'windowed';

  sizes.forEach((size) => {
    let i = 0;
    pages.forEach((page) => {
      it(`bp.${os}.${mode}.${size}.${page}`, () => {
        prepareTest(page, size);
        cy.get(indicator[i]);
        if (i == 3) {
          //just this element is in need of bluring
          cy.focused().blur({ force: true });
        }
        // eslint-disable-next-line cypress/no-unnecessary-waiting
        cy.wait(1000);
        cy.matchImageSnapshot(`bp.${os}.${mode}.${size}.${page}`);
        i++;
      });
    });
  });
});
