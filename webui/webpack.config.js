const { join } = require('path');

const { createWebpackConfiguration, initEnv } = require('@tarantool.io/webpack-config');
const { namespace } = require('./module-config');

const env = initEnv();

const root = __dirname;
const entry = process.env.WEBPACK_APP_ENTRY || 'index.js';

const isProd = env.NODE_ENV === 'production';

module.exports = createWebpackConfiguration({
  namespace,
  root,
  entry: join(root, 'src', entry),
  htmlTemplate: !isProd ? join(root, 'public', 'index.html') : undefined,
  lua: true,
  lint: true,
  emotion: true,
  env,
  sourceMap: process.env.GENERATE_SOURCEMAP === 'true',
  proxy: process.env.WEBPACK_DEV_SERVER_PROXY === 'true' ? require('./config/proxy.config') : undefined,
  externals: isProd
    ? {
        react: 'react',
        'react-dom': 'reactDom',
        '@tarantool.io/frontend-core': 'tarantool_frontend_core_module',
        // '@tarantool.io/ui-kit': 'tarantool_frontend_ui_kit_module',
      }
    : {
        react: 'react',
        'react-dom': 'reactDom',
        // '@tarantool.io/ui-kit': 'tarantool_frontend_ui_kit_module',
      },
  middleware: isProd
    ? (cfg) => {
        cfg.cache = false;
        return cfg;
      }
    : undefined,
});
