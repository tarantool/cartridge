import { getGraphqlError, isGraphqlErrorResponse } from './graphql';

const makeGraphQLError = (message, extensions = undefined) => ({
  message,
  extensions,
});

const makeErrorResponse = (gqlErrors) => {
  return {
    graphQLErrors: gqlErrors,
    networkError: null,
    message: 'GraphQL error: "localhost:3303": Connection refused',
    lineNumber: 39247,
    columnNumber: 24,
    extraInfo: undefined,
    stack: 'ApolloError@http://localhost:3001/static/js/bundle.js:39247:24\nnext@...',
    fileName: 'http://localhost:3001/static/js/bundle.js',
  };
};

describe('isGraphqlErrorResponse', () => {
  it('does not give a false-negative result', () => {
    const error = makeGraphQLError('"localhost:3303": Connection refused', {
      'io.tarantool.errors.class_name': 'NetboxConnectError',
      'io.tarantool.errors.stack':
        'stack traceback:\n\t' +
        ".../cartridge/cartridge/pool.lua:125: in function 'connect'\n\t" +
        '.../cartridge/cartridge/pool.lua:144: in function ' +
        '<.../cartridge/cartridge/pool.lua:142>',
    });
    const apiResponse = makeErrorResponse([error]);

    expect(isGraphqlErrorResponse(apiResponse)).toBe(true);
  });

  it('does not give a false-positive result', () => {
    const apiResponse = makeErrorResponse([]);
    expect(isGraphqlErrorResponse(apiResponse)).toBe(false);
  });
});

describe('getGraphqlError', () => {
  it('correctly returns first graphql error in response', () => {
    const error1 = makeGraphQLError('message', {
      'io.tarantool.errors.stack': 'some stack',
    });
    const error2 = {};
    const error3 = {};

    const apiResponse = makeErrorResponse([error1, error2, error3]);

    expect(getGraphqlError(apiResponse)).toEqual(error1);
  });
});
