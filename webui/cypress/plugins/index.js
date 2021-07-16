/// <reference types="cypress" />
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

/**
 * @type {Cypress.PluginConfig}
 */
const net = require('net');
const yaml = require('js-yaml');
const cache = {};

function connect(host, port) {
  return new Promise((resolve, reject) => {
    const addr = host + ':' + port;

    if (cache[addr] && !cache[addr].destroyed) {
      resolve(cache[addr]);
      return;
    }

    const conn = net.connect(port, host);
    cache[addr] = conn;
    conn.setEncoding('utf8');

    // Fetch the greeting
    const _on_data = data => {
      conn.off('data', _on_data);
      resolve(conn);
    }

    const _on_error = error => {
      conn.off('error', _on_error);
      reject(error);
    }

    conn.on('data', _on_data);
    conn.on('error', _on_error);
  });
}

function communicate(conn, text) {
  return new Promise(resolve => {
    conn.write(text);
    const chunks = [];

    const _on_data = data => {
      chunks.push(data);
      if (data.endsWith('\n...\n')) {
        conn.off('data', _on_data);
        const resp = chunks.join('')
        resolve(resp);
      }
    }
    conn.on('data', _on_data);
  })
}

module.exports = (on, config) => {
  on('task', {
    async tarantool({
      host = config.env.launcherHost,
      port = config.env.launcherPort,
      code
    }) {
      const conn = await connect(host, port);
      const fcmd = code.split('\n').join(' ') + '\n';
      const resp = yaml.safeLoad(await communicate(conn, fcmd));

      if (resp && resp[0] && resp[0].error) {
        throw new Error(resp[0].error)
      }

      return resp;
    }
  })
}
