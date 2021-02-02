// @flow
import * as React from 'react';
import { defaultMemoize } from 'reselect';
import { connect } from 'react-redux';
import { FlatList } from './FlatList';
import ReplicasetServerListItem from 'src/components/ReplicasetServerListItem';
import type { Replicaset } from 'src/generated/graphql-typing';

const prepareServers = (replicaset: Replicaset) => {
  const masterUuid = replicaset.master.uuid;
  const activeMasterUuid = replicaset.active_master.uuid;
  return replicaset.servers.map(server => ({
    ...server,
    master: server.uuid === masterUuid,
    activeMaster: server.uuid === activeMasterUuid
  }));
};

type ReplicasetServerListProps = {
  clusterSelf: any,
  failoverMode: string,
  replicaset: Replicaset,
  editReplicaset: (r: Replicaset) => void,
  onServerLabelClick: () => void
};

class ReplicasetServerList extends React.PureComponent<ReplicasetServerListProps> {
  render() {
    const { clusterSelf, failoverMode, onServerLabelClick, replicaset } = this.props;
    const servers = this.getServers();

    return (
      servers
        ? (
          <FlatList className='meta-test__ReplicasetServerList'>
            {servers.map(server => (
              <ReplicasetServerListItem
                onServerLabelClick={onServerLabelClick}
                totalBucketsCount={clusterSelf && clusterSelf.vshard_bucket_count}
                replicasetUUID={replicaset.uuid}
                selfURI={clusterSelf && clusterSelf.uri}
                showFailoverPromote={servers && servers.length > 1 && failoverMode === 'stateful'}
                {...server}
              />
            ))}
          </FlatList>
        )
        : null
    );
  }

  handleEditReplicasetClick = () => {
    const { replicaset, editReplicaset } = this.props;
    editReplicaset(replicaset);
  };

  getServers = () => {
    const { replicaset } = this.props;
    return this.prepareServers(replicaset);
  };

  prepareServers = defaultMemoize(prepareServers);
}

const mapStateToProps = ({ app: { failover_params: { mode: failoverMode } } }) => ({ failoverMode });

export default connect(mapStateToProps)(ReplicasetServerList);
