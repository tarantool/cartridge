const { exec } = require('child_process');

describe('Replicaset configuration', () => {
  it('creates replicaset with vshard-router and myrole roles', () => {
    cy.visit(Cypress.config('baseUrl'));

    cy.get('.page-inner').contains('Create').eq(0).click();
    cy.get('.ant-modal .ant-form-item-children .ant-row label').eq(2).contains('vshard-router').click();
    cy.get('.ant-modal .ant-form-item-children .ant-row label').eq(0).contains('myrole').click();

    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(0).should('be.checked');
    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(1).should('be.checked');
    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(2).should('be.checked');
    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(3).should('not.be.checked');

    cy.get('.ant-modal button[type=button]').contains('Submit').parent().click();

    cy.contains('Replica sets (1 total, 0 unhealthy) (1 server)', { timeout: 10000 });
  });

  it('creates replicaset with vshard-storage role', () => {
    cy.get('.page-inner').contains('Create').eq(0).click();
    cy.get('.ant-modal .ant-form-item-children .ant-row label').eq(3).contains('vshard-storage').click();

    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(0).should('not.be.checked');
    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(1).should('not.be.checked');
    cy.get('.ant-modal .ant-checkbox-wrapper input').eq(2).should('not.be.checked');

    cy.get('.ant-modal button[type=button]').contains('Submit').parent().click();

    cy.contains('Replica sets (2 total, 0 unhealthy) (2 servers)', { timeout: 10000 });
  });

  it('unconfigured servers joins created replicasets', () => {
    cy.get('.page-inner').contains('Join').eq(0).click();
    cy.get('.ant-modal .ant-form-item-children .ant-row label').eq(0).click();
    cy.get('.ant-modal button[type=button]').contains('Submit').parent().click();
    cy.contains('Replica sets (2 total, 0 unhealthy) (3 servers)', { timeout: 10000 });

    cy.get('.page-inner').contains('Join').eq(0).click();
    cy.get('.ant-modal .ant-form-item-children .ant-row label').eq(1).click();
    cy.get('.ant-modal button[type=button]').contains('Submit').parent().click();
    cy.contains('Replica sets (2 total, 0 unhealthy) (4 servers)', { timeout: 10000 });

    cy.get('.page-inner').contains('Join').eq(0).click();
    cy.get('.ant-modal .ant-form-item-children .ant-row label').eq(1).click();
    cy.get('.ant-modal button[type=button]').contains('Submit').parent().click();
    cy.contains('Replica sets (2 total, 0 unhealthy) (5 servers)', { timeout: 10000 });
  });

  // cy.get('body').trigger('keydown', { keycode: 27, which: 27 });
});
