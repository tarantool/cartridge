import core from '@tarantool.io/frontend-core';

const apiPrefix = core.adminPrefix;

if (!navigator.userAgent.includes('jsdom')) {
  // eslint-disable-next-line no-undef
  __webpack_public_path__ = apiPrefix + '/';
}

const apiEndpoints = {
  LSP_ENDPOINT: apiPrefix + process.env.REACT_APP_LSP_ENDPOINT,
  DOCS_ENDPOINT: apiPrefix + process.env.REACT_APP_DOCS_ENDPOINT,
  CONFIG_ENDPOINT: apiPrefix + process.env.REACT_APP_CONFIG_ENDPOINT,
  SOAP_API_ENDPOINT: apiPrefix + process.env.REACT_APP_SOAP_API_ENDPOINT,
  LOGIN_API_ENDPOINT: apiPrefix + process.env.REACT_APP_LOGIN_API_ENDPOINT,
  LOGOUT_API_ENDPOINT: apiPrefix + process.env.REACT_APP_LOGOUT_API_ENDPOINT,
  GRAPHQL_API_ENDPOINT: apiPrefix + process.env.REACT_APP_GRAPHQL_API_ENDPOINT,
};

export const getApiEndpoint = (alias) => {
  return apiEndpoints[alias];
};
