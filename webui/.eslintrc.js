module.exports = {
  extends: [
    '@tarantool.io/eslint-config',
    '@tarantool.io/eslint-config/react',
    '@tarantool.io/eslint-config/emotion',
    '@tarantool.io/eslint-config/cypress',
  ],
  settings: {
    'import/resolver': {
      node: {
        extensions: ['.js', '.jsx', '.ts', '.tsx'],
        moduleDirectory: ['node_modules', '.'],
      },
    },
  },
  overrides: [
    {
      files: ['*.test.js', '*.spec.js'],
      rules: {
        'sonarjs/no-duplicate-string': 'off',
      },
    },
  ],
  rules: {
    'sonarjs/cognitive-complexity': 'off',
    'no-console': 'off',
  },
};
