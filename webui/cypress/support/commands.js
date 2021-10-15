// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add("login", (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add("drag", { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add("dismiss", { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite("visit", (originalFn, url, options) => { ... })

// https://www.npmjs.com/package/cypress-file-upload
import 'cypress-file-upload';

import { addMatchImageSnapshotCommand } from 'cypress-image-snapshot/command';

addMatchImageSnapshotCommand({
  // Doc: https://github.com/americanexpress/jest-image-snapshot
  capture: 'viewport',

  // We use high per-pixel threshold to ignore color difference.
  comparisonMethod: 'pixelmatch',
  customDiffConfig: { threshold: 0.1 }, // 10%

  // But the failure threshold is low to catch a single pixel.
  failureThresholdType: 'percent',
  failureThreshold: 0.001, // 0%
});

require('cypress-downloadfile/lib/downloadFileCommand');

Cypress.Commands.add('setResolution', (size) => {
  const [w, h] = size.split('x');
  cy.viewport(parseInt(w), parseInt(h));
});

const sizes = ['1280x720', '1440x900', '1920x1080'];
Cypress.Commands.add('testScreenshots', (name) => {
  sizes.forEach((size) => {
    cy.setResolution(size);
    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(1000);
    cy.matchImageSnapshot(`${name}.${size}`);
  });
});

Cypress.Commands.add('testElementScreenshots', (name, cssSelector) => {
  sizes.forEach((size) => {
    cy.setResolution(size);
    // eslint-disable-next-line cypress/no-unnecessary-waiting
    cy.wait(1000);
    cy.get(cssSelector).matchImageSnapshot(`${name}.${size}`);
  });
});
