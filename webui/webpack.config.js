const { join } = require('path');

const { createWebpackConfiguration, initEnv } = require('@tarantool.io/webpack-config');
const { namespace } = require('./module-config');

const env = initEnv();

const proxy = require('./config/proxy.config');

const root = __dirname;
const entry = process.env.WEBPACK_APP_ENTRY || 'index.js';

module.exports = createWebpackConfiguration({
  namespace,
  root,
  entry: join(root, 'src', entry),
  htmlTemplate: env.NODE_ENV !== 'production' ? join(root, 'public', 'index.html') : undefined,
  analyze: false,
  lua: true,
  env,
  sourceMap: true,
  proxy: process.env.WEBPACK_DEV_SERVER_PROXY === 'true' ? proxy : undefined,
  externals: {
    react: 'react',
    'react-dom': 'reactDom',
  },
});
