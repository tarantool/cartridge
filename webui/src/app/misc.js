import { encodeURIComponent } from 'src/misc/url';

export const getServerName = (server, clusterSelf) => {
  let name = server.alias || server.uri;
  if (server.uri === clusterSelf.uri) {
    name = `${name}(i)`;
  }
  return name;
};

export const getServerConsoleFullUrl = (server, clusterSelf) => {
  let url = '/console';
  if (server.uuid !== clusterSelf.uuid) {
    url = `${url}/${encodeURIComponent(server.uuid)}`;
  }
  return url;
};
