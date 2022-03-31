module.exports = {
  collectCoverageFrom: ['src/**/*.{js,jsx,ts,tsx,mjs}'],
  setupFiles: ['@tarantool.io/webpack-config/polyfills.js'],
  testMatch: [
    '<rootDir>/src/**/__tests__/**/*.{js,jsx,ts,tsx,mjs}',
    '<rootDir>/src/**/?(*.)(spec|test).{js,jsx,ts,tsx,mjs}',
  ],
  testEnvironment: 'node',
  testURL: 'http://localhost',
  transform: {
    '^.+\\.(js|jsx|mjs)$': 'babel-jest',
    '^.+\\.(ts|tsx)$': 'ts-jest',
    '^.+\\.css$': '<rootDir>/config/jest/cssTransform.js',
    '^(?!.*\\.(js|jsx|ts|tsx|mjs|css|json)$)': '<rootDir>/config/jest/fileTransform.js',
  },
  transformIgnorePatterns: ['[/\\\\]node_modules[/\\\\].+\\.(js|jsx|mjs)$'],
  moduleNameMapper: {
    '^src/(.*)$': '<rootDir>/src/$1',
    '^~/(.*)$': '<rootDir>/src/$1',
  },
  moduleFileExtensions: ['web.js', 'js', 'ts', 'json', 'web.jsx', 'jsx', 'tsx', 'node', 'mjs'],
};
