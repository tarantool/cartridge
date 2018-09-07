import PropTypes from 'prop-types';
import React from 'react';

import ServerList from 'src/components/ServerList';
import cn from 'src/misc/cn';

import './ReplicasetCard.css';

class ReplicasetCard extends React.PureComponent {
  render() {
    const { clusterSelf, replicaset, consoleServer, joinServer, expellServer, createReplicaset } = this.props;
    const shortUuid = replicaset.uuid.slice(0, 8);
    const rolesString = replicaset.roles.join(', ');
    const indicatorClassName = cn(
      'ReplicasetCard-indicator',
      replicaset.status !== 'healthy' && 'ReplicasetCard-indicator--error',
    );

    return (
      <div className="ReplicasetCard">
        <div className="ReplicasetCard-head">
          <div className="ReplicasetCard-name">
            <span className={indicatorClassName} />
            <span className="ReplicasetCard-namePrimary">{shortUuid}</span>
            <span className="ReplicasetCard-nameSecondary">{rolesString}</span>
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
        {replicaset.servers
          ? (
            <div className="ReplicasetCard-serverList">
              <ServerList
                skin="light"
                linked
                clusterSelf={clusterSelf}
                dataSource={replicaset.servers}
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
