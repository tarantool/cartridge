import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import { css } from 'react-emotion';

import ServerList from 'src/components/ServerList';
import HealthIndicator from 'src/components/HealthIndicator';

import './ReplicasetCard.css';

const styles = {
  editButton: css`
    display: inline-block;
    padding: 8px 0px;
    min-width: 115px;
    text-align: center;
    cursor: pointer;
    border-radius: 6px;
    background: #fff;
    font-size: 12px;
    font-family: Roboto;
    color: #000;
    border: none;
  `
};

const prepareServers = replicaset => {
  const masterUuid = replicaset.master.uuid;
  const activeMasterUuid = replicaset.active_master.uuid;
  return replicaset.servers.map(server => ({
    ...server,
    master: server.uuid === masterUuid,
    activeMaster: server.uuid === activeMasterUuid,
  }));
};

const prepareRolesText = (roles, weight) => {
  return roles
    .map(role => role === 'vshard-storage' && weight != null ? `${role} (weight: ${weight})` : role)
    .join(', ');
};

class ReplicasetCard extends React.PureComponent {
  render() {
    const {
      clusterSelf,
      replicaset,
      consoleServer,
      joinServer,
      expelServer,
      createReplicaset,
      onServerLabelClick
    } = this.props;
    const shortUuidText = replicaset.uuid.slice(0, 8);
    const rolesText = this.getRolesText();
    const servers = this.getServers();

    return (
      <div className="ReplicasetCard">
        <div className="ReplicasetCard-head">
          <div className="ReplicasetCard-name">
            <HealthIndicator
              className="ReplicasetCard-indicator"
              size="m"
              state={replicaset.status === 'healthy' ? 'good' : 'bad'}
            />
            <span className="ReplicasetCard-namePrimary">{shortUuidText}</span>
            <span className="ReplicasetCard-nameSecondary">{rolesText}</span>
          </div>
          <div className="ReplicasetCard-actions">
            <button
              type="button"
              className={styles.editButton}
              onClick={this.handleEditReplicasetClick}
            >
              Edit
            </button>
          </div>
        </div>
        {servers
          ? (
            <div className="ReplicasetCard-serverList">
              <ServerList
                skin="light"
                linked
                clusterSelf={clusterSelf}
                dataSource={servers}
                consoleServer={consoleServer}
                joinServer={joinServer}
                expelServer={expelServer}
                createReplicaset={createReplicaset}
                onServerLabelClick={onServerLabelClick}
              />
            </div>
          )
          : null}
      </div>
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

  getRolesText = () => {
    const { replicaset: { roles, weight } } = this.props;
    return this.prepareRolesText(roles, weight);
  };

  prepareServers = defaultMemoize(prepareServers);

  prepareRolesText = defaultMemoize(prepareRolesText)
}

ReplicasetCard.propTypes = {
  clusterSelf: PropTypes.any,
  replicaset: PropTypes.shape({
    uuid: PropTypes.string.isRequired,
    roles: PropTypes.arrayOf(PropTypes.string).isRequired,
    status: PropTypes.string,
    servers: PropTypes.array.isRequired,
  }).isRequired,
  editReplicaset: PropTypes.func.isRequired,
  joinServer: PropTypes.func.isRequired,
  expelServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
  onServerLabelClick: PropTypes.func
};

export default ReplicasetCard;
