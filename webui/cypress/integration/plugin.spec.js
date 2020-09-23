describe('Test the plugin', () => {

  it('return result', () => {
    cy.task('tarantool', {code: `
      print('Hello, Tarantool!')
      return 1, 2, 3
    `}).should('deep.eq', [1, 2, 3]);
  });

  it.skip('tarantool raises', () => {
    cy.task('tarantool', {
      code: `error('Artificial error')`
    });
  });

  it.skip('connection refused', () => {
    cy.task('tarantool', {host: 'unix/', port: '/dev/null', code: `
      return true
    `});
  });

});
