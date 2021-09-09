const { join } = require('path');

module.exports = {
  extends: [
    '@tarantool.io/eslint-config',
    '@tarantool.io/eslint-config/react',
    '@tarantool.io/eslint-config/emotion',
    '@tarantool.io/eslint-config/cypress',
  ],
  settings: {
    'import/resolver': {
      alias: [
        ['src', join(__dirname, 'src')],
        ['~', join(__dirname, 'src')],
      ],
    },
  },
  rules: {
    'sonarjs/cognitive-complexity': 'off',
  },
};
