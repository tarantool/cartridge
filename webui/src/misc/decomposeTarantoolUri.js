// @flow

type DecomposedUri = {
  user: string,
  password: string,
  host: string,
  port: string,
};

export const decomposeTarantoolUri = (uri: string): DecomposedUri => {
  const [credentials, server] = uri.split('@');
  const [user, password] = credentials.split(':');
  const [host, port] = server.split(':');
  return {
    user,
    password,
    host,
    port,
  };
};

export const validateTarantoolUri = (uri: string): boolean => {
  try {
    const { user, password, host, port } = decomposeTarantoolUri(uri);
    return !!(user && password && host && port);
  } catch (e) {
    return false;
  }
};
