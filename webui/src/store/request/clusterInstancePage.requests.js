import graphql from 'src/api/graphql';
import { firstServerDetailsQuery, nextServerDetailsQuery } from './queries.graphql';

const descriptionsByName = ({ fields = [] } = {}) => fields.reduce((acc, item) => {
  acc[item.name] = item.description;
  return acc;
}, {})

export function getInstanceData({ instanceUUID }) {

  return graphql.fetch(firstServerDetailsQuery, { uuid: instanceUUID })
    .then(({
      servers,
      descriptionCartridge,
      descriptionGeneral,
      descriptionNetwork,
      descriptionReplication,
      descriptionStorage,
      descriptionMembership,
      descriptionVshardRouter,
      descriptionVshardStorage,
    }) => {
      const {
        alias,
        boxinfo = {},
        labels,
        message,
        replicaset: {
          active_master: {
            uuid: activeMasterUUID
          },
          master: {
            uuid: masterUUID
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
          cartridge: descriptionsByName(descriptionCartridge),
          general: descriptionsByName(descriptionGeneral),
          network: descriptionsByName(descriptionNetwork),
          replication: descriptionsByName(descriptionReplication),
          storage: descriptionsByName(descriptionStorage),
          membership: descriptionsByName(descriptionMembership),
          vshard_router: descriptionsByName(descriptionVshardRouter),
          vshard_storage: descriptionsByName(descriptionVshardStorage),
        }
      }
    });
}

export function refreshInstanceData({ instanceUUID }) {
  return graphql.fetch(nextServerDetailsQuery, { uuid: instanceUUID })
    .then(({ servers }) => ({
      boxinfo: servers[0].boxinfo || {},
      labels: servers[0].labels || []
    }));
}
