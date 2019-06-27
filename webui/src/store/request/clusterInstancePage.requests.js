import graphql from 'src/api/graphql';
import {boxInfoQuery, instanceDataQuery} from "./queries.graphql";

const descriptionsByName = ({ fields = [] } = {}) => fields.reduce((acc, item) => {
  acc[item.name] = item.description;
  return acc;
}, {})

export function getInstanceData({ instanceUUID }) {

  return graphql.fetch(instanceDataQuery, { uuid: instanceUUID })
    .then(({
      servers,
      descriptionGeneral,
      descriptionNetwork,
      descriptionReplication,
      descriptionStorage,
    }) => {
      const {
        alias,
        boxinfo = {},
        labels,
        message,
        replicaset: {
          active_master: {
            uuid: masterUUID
          },
          master: {
            uuid: activeMasterUUID
          },
          roles
        },
        status,
        uri
      } = servers[0];

      return {
        alias,
        boxinfo,
        labels,
        message,
        masterUUID,
        activeMasterUUID,
        roles,
        status,
        uri,
        descriptions: {
          general: descriptionsByName(descriptionGeneral),
          network: descriptionsByName(descriptionNetwork),
          replication: descriptionsByName(descriptionReplication),
          storage: descriptionsByName(descriptionStorage)
        }
      }
    });
}

export function refreshInstanceData({ instanceUUID }) {
  return graphql.fetch(boxInfoQuery, {uuid: instanceUUID})
    .then(({ servers }) => ({
      boxinfo: servers[0].boxinfo || {},
      labels: servers[0].labels || []
    }));
}
