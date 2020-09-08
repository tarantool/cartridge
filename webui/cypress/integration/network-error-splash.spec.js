// TODO:
// - Test cases with SIGSTOP+SIGCONT
// - Think about adding request timeouts to apollo and axios
// - Improve this test when cypress network features will be done
//   (https://github.com/cypress-io/cypress/issues/687)

describe('Error network panel not visible in normal state', () => {
  it('On cluster page', () => {
    cy.visit(Cypress.config('baseUrl'));
    cy.get('.meta-test__ProbeServerBtn');
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');
  });

  it('On users page', () => {
    cy.get('a[href="/admin/cluster/users"]').click();
    cy.get('.meta-test__UsersTable').contains('Cartridge Administrator');
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');
  })

  it('On config page', () => {
    cy.get('a[href="/admin/cluster/configuration"]').click();
    cy.get('#root').contains('Download configuration');
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');
  })

  it('On editor page', () => {
    cy.get('a[href="/admin/cluster/code"]').click();
    cy.get('.meta-test__Code__reload_idle');
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');
  })

  it('On schema page', () => {
    cy.get('a[href="/admin/cluster/schema"]').click();
    cy.get('.monaco-editor textarea');
    cy.get('.meta-test__NetworkErrorSplash').should('not.exist');
  })
});

describe('Error network panel visible when server not respond', () => {
  it('On cluster page', () => {
    cy.exec('kill -SIGKILL $(lsof -sTCP:LISTEN -i :8081 -t)', { failOnNonZeroExit: true });
    cy.get('a[href="/admin/cluster/dashboard"]', { timeout: 8000 }).click();
    cy.get('.meta-test__NetworkErrorSplash').contains('Network connection problem or server disconnected');
  })

  it('On users page', () => {
    cy.get('a[href="/admin/cluster/users"]', { timeout: 8000, force: true }).click();
    cy.get('.meta-test__NetworkErrorSplash').contains('Network connection problem or server disconnected');
  })

  it('On config page', () => {
    cy.get('a[href="/admin/cluster/configuration"]', { timeout: 8000, force: true }).click();
    cy.get('.meta-test__NetworkErrorSplash').contains('Network connection problem or server disconnected');
  })

  it('On editor page', () => {
    cy.get('a[href="/admin/cluster/code"]', { timeout: 8000, force: true }).click();
    cy.get('.meta-test__NetworkErrorSplash').contains('Network connection problem or server disconnected');
  })

  it('On schema page', () => {
    cy.on('uncaught:exception', (err, runnable) => {
      expect(err.message).to.include('something about the error')
      // return false to prevent the error from
      // failing this test
      return false
    })

    cy.get('a[href="/admin/cluster/schema"]', { timeout: 8000}).click();
    cy.get('.meta-test__NetworkErrorSplash').contains('Network connection problem or server disconnected');
  })
});

// describe('Error network panel disappears when reconnecting', () => {
//   it('On cluster page', () => {
//     cy.exec('kill -SIGCONT $(lsof -sTCP:LISTEN -i :3301 -t)', { failOnNonZeroExit: false })
//     cy.get('a[href="/admin/cluster/dashboard"]').click();
//     cy.get('.meta-test__NetworkErrorSplash').should('not.exist')
//   });

//   it('On users page', () => {
//     cy.get('a[href="/admin/cluster/users"]').click();
//     cy.get('.meta-test__NetworkErrorSplash').should('not.exist')
//   })

//   it('On config page', () => {
//     cy.get('a[href="/admin/cluster/configuration"]').click();
//     cy.get('.meta-test__NetworkErrorSplash').should('not.exist')
//   })

//   it('On editor page', () => {
//     cy.get('a[href="/admin/cluster/code"]').click();
//     cy.get('.meta-test__NetworkErrorSplash').should('not.exist')
//   })

//   it('On schema page', () => {
//     cy.get('a[href="/admin/cluster/schema"]').click();
//     cy.get('.meta-test__NetworkErrorSplash').should('not.exist')
//   })
// });
