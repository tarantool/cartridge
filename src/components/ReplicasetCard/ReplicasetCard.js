import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import ServerList from 'src/components/ServerList';
import cn from 'src/misc/cn';

import './ReplicasetCard.css';

const prepareServers = replicaset => {
  const masterUuid = replicaset.master.uuid;
  return replicaset.servers.map(server =>  ({ ...server, master: server.uuid === masterUuid }));
};

class ReplicasetCard extends React.PureComponent {
  render() {
    const { clusterSelf, replicaset, consoleServer, joinServer, expellServer, createReplicaset } = this.props;
    const shortUuidText = replicaset.uuid.slice(0, 8);
    const rolesText = replicaset.roles.join(', ');
    const indicatorClassName = cn(
      'ReplicasetCard-indicator',
      replicaset.status !== 'healthy' && 'ReplicasetCard-indicator--error',
    );
    const servers = this.getServers();

    return (
      <div className="ReplicasetCard">
        <div className="ReplicasetCard-head">
          <div className="ReplicasetCard-name">
            <span className={indicatorClassName} />
            <span className="ReplicasetCard-namePrimary">{shortUuidText}</span>
            <span className="ReplicasetCard-nameSecondary">{rolesText}</span>
          </div>
          <div className="ReplicasetCard-actions">
            <button
              type="button"
              className="btn btn-light btn-sm"
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
                expellServer={expellServer}
                createReplicaset={createReplicaset} />
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

  prepareServers = defaultMemoize(prepareServers);
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
  expellServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
};

export default ReplicasetCard;
