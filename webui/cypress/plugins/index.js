const { exec } = require('child_process');

// ***********************************************************
// This example plugins/index.js can be used to load plugins
//
// You can change the location of this file or turn off loading
// the plugins file with the 'pluginsFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/plugins-guide
// ***********************************************************

// This function is called when a project is opened or re-opened (e.g. due to
// the project's config changing)

module.exports = (on, config) => {
  // `on` is used to hook into various events Cypress emits
  // `config` is the resolved Cypress config
  on('task', {
    refreshTarantool() {
      return new Promise((resolve, reject) => {
        exec(
          'cd .. && ./stop.sh && rm -rf ./dev && ./start.sh',
          (error, stdout, stderr) => error ? reject({ error, stderr }) : resolve(stdout)
        );

        setTimeout(() => resolve(null), 3000)
      })
    },

    startTarantool() {
      return new Promise((resolve, reject) => {
        exec('cd .. && ./start.sh', (error, stdout, stderr) => error ? reject({ error, stderr }) : resolve(stdout));

        setTimeout(() => resolve(null), 3000)
      })
    },

    stopTarantool() {
      return new Promise((resolve, reject) => {
        exec('cd .. && ./stop.sh', (error, stdout, stderr) => error ? reject({ error, stderr }) : resolve(stdout));
      })
    },

    wipeTarantool() {
      return new Promise((resolve, reject) => {
        exec(
          'cd .. && ./stop.sh && rm -rf ./dev',
          (error, stdout, stderr) => error ? reject({ error, stderr }) : resolve(stdout)
        );
      })
    }
  });
};
