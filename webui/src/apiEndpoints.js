const apiEndpoints = {
  LSP_ENDPOINT: process.env.REACT_APP_LSP_ENDPOINT,
  DOCS_ENDPOINT: process.env.REACT_APP_DOCS_ENDPOINT,
  CONFIG_ENDPOINT: process.env.REACT_APP_CONFIG_ENDPOINT,
  SOAP_API_ENDPOINT: process.env.REACT_APP_SOAP_API_ENDPOINT,
  LOGIN_API_ENDPOINT: process.env.REACT_APP_LOGIN_API_ENDPOINT,
  LOGOUT_API_ENDPOINT: process.env.REACT_APP_LOGOUT_API_ENDPOINT,
  GRAPHQL_API_ENDPOINT: process.env.REACT_APP_GRAPHQL_API_ENDPOINT,
}

const apiPrefix = window.__tarantool_admin_prefix || ''
if (apiPrefix.length > 0) {
  __webpack_public_path__ = apiPrefix + '/'
  Object.keys(apiEndpoints).forEach(key => apiEndpoints[key] = apiPrefix + apiEndpoints[key])
}

export const getApiEndpoint = alias => {
  return apiEndpoints[alias]
}
