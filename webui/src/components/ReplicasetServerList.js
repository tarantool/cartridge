// @flow
import * as React from 'react';
import { defaultMemoize } from 'reselect';
import { css } from 'react-emotion';
import { FlatList } from '@tarantool.io/ui-kit';
import ReplicasetServerListItem from 'src/components/ReplicasetServerListItem';
import type {
  Replicaset
} from 'src/generated/graphql-typing';

const SERVER_LABELS_HIGHLIGHTING_CLASS = 'ServerLabelsHighlightingArea';

const styles = {
  server: css`
    position: relative;
    padding-left: 32px;
  `,
  row: css`
    display: flex;
    align-items: baseline;
    margin-bottom: 4px;
  `,
  heading: css`
    flex-basis: 480px;
    flex-grow: 1;
    margin-right: 12px;
  `,
  leaderFlag: css`
    position: absolute;
    top: 0;
    left: 3px;
  `,
  iconMargin: css`
    margin-right: 4px;
  `,
  memProgress: css`
    width: 183px;
    margin-left: 24px;
  `,
  configureBtn: css`
    margin-left: 8px;
  `,
  status: css`
    display: flex;
    flex-basis: 153px;
    align-items: center;
    margin-right: 12px;
    margin-left: 12px;
  `,
  stats: css`
    position: relative;
    display: flex;
    flex-basis: 351px;
    align-items: center;
    margin-right: 12px;
    margin-left: 12px;

    & > *:first-child {
      position: relative;
      margin-right: 17px;
    }

    & > *:first-child::before {
      content: '';
      position: absolute;
      top: 0px;
      right: -8px;
      width: 1px;
      height: 18px;
      background-color: #e8e8e8;
    }
  `
};

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
  replicaset: Replicaset,
  editReplicaset: (r: Replicaset) => void,
  onServerLabelClick: () => void
};

class ReplicasetServerList extends React.PureComponent<ReplicasetServerListProps> {
  render() {
    const { clusterSelf, onServerLabelClick } = this.props;
    const servers = this.getServers();

    return (
      servers
        ? (
          <React.Fragment>
            <FlatList
              className='ReplicasetServerList'
              itemClassName={`${styles.server} ${SERVER_LABELS_HIGHLIGHTING_CLASS}`}
              items={servers}
              itemRender={server => (
                <ReplicasetServerListItem
                  onServerLabelClick={onServerLabelClick}
                  tagsHighlightingClassName={SERVER_LABELS_HIGHLIGHTING_CLASS}
                  totalBucketsCount={clusterSelf && clusterSelf.vshard_bucket_count}
                  {...server}
                />
              )}
            />
          </React.Fragment>
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

export default ReplicasetServerList;
