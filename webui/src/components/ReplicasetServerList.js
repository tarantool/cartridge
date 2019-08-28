// @flow
// TODO: move to uikit
import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import { css } from 'react-emotion';
import FlatList from 'src/components/FlatList';
import ReplicasetServerListItem from 'src/components/ReplicasetServerListItem';

const SERVER_LABELS_HIGHLIGHTING_CLASS = 'ServerLabelsHighlightingArea'

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

const prepareServers = replicaset => {
  const masterUuid = replicaset.master.uuid;
  const activeMasterUuid = replicaset.active_master.uuid;
  return replicaset.servers.map(server => ({
    ...server,
    master: server.uuid === masterUuid,
    activeMaster: server.uuid === activeMasterUuid
  }));
};

class ReplicasetServerList extends React.PureComponent {
  render() {
    const { onServerLabelClick } = this.props;
    const servers = this.getServers();

    return (
      servers
        ? (
          <React.Fragment>
            <FlatList
              itemClassName={`${styles.server} ${SERVER_LABELS_HIGHLIGHTING_CLASS}`}
              items={servers}
              itemRender={server => (
                <ReplicasetServerListItem
                  onServerLabelClick={onServerLabelClick}
                  tagsHighlightingClassName={SERVER_LABELS_HIGHLIGHTING_CLASS}
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

ReplicasetServerList.propTypes = {
  clusterSelf: PropTypes.any,
  replicaset: PropTypes.shape({
    uuid: PropTypes.string.isRequired,
    roles: PropTypes.arrayOf(PropTypes.string).isRequired,
    status: PropTypes.string,
    servers: PropTypes.array.isRequired
  }).isRequired,
  editReplicaset: PropTypes.func.isRequired,
  expelServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
  onServerLabelClick: PropTypes.func
};

export default ReplicasetServerList;
