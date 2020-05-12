describe('Auth switcher not moved', () => {

    it('Auth switcher not moved', () => {
      cy.visit(Cypress.config('baseUrl'));
      //try to find Auth switcher on Users Page: success
      cy.get('a[href="/admin/cluster/users"]').click();
      cy.get('.meta-test__AuthToggle').should('exist');
      //try to find Auth switcher on Cluster Page: fail
      cy.get('a[href="/admin/cluster/dashboard"]').click();
      cy.get('.meta-test__AuthToggle').should('not.exist');
    })
});
