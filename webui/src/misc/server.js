// @flow
type Server = {
  alias?: string,
  uri: string,
};

export const formatServerName = (server: Server) => (server.alias ? server.alias : server.uri);
