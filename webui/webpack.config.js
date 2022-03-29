const { join } = require('path');

const { createWebpackConfiguration, initEnv } = require('@tarantool.io/webpack-config');

const { namespace } = require('./module-config');

const env = initEnv();

const isServe = process.env['WEBPACK_SERVE'] === 'true';
const isProd = env['NODE_ENV'] === 'production';

const root = __dirname;
const entry = join(root, 'src', process.env['WEBPACK_APP_ENTRY'] || 'index.js');
const build = join(root, 'build');
const htmlTemplate = isServe ? join(root, 'public', 'index.html') : undefined;
const proxy = process.env.WEBPACK_DEV_SERVER_PROXY === 'true' ? require('./config/proxy.config') : undefined;
const sourceMap = process.env.GENERATE_SOURCEMAP === 'true';

module.exports = createWebpackConfiguration({
  namespace,
  root,
  entry,
  build,
  htmlTemplate,
  lua: isProd && !isServe,
  lint: true,
  emotion: true,
  env,
  sourceMap,
  proxy,
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
