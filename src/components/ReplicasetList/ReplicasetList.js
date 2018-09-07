import PropTypes from 'prop-types';
import React from 'react';

import ReplicasetCard from 'src/components/ReplicasetCard';

import './ReplicasetList.css';

class ReplicasetList extends React.PureComponent {
  render() {
    const { clusterSelf, dataSource, consoleServer, editReplicaset, joinServer, expellServer, createReplicaset } = this.props;

    return (
      <div className="ReplicasetList-outer">
        <div className="ReplicasetList-inner">
          {dataSource.map(replicaset => {
            return (
              <div
                key={replicaset.uuid}
                className="ReplicasetList-replicasetCard"
              >
                <ReplicasetCard
                  clusterSelf={clusterSelf}
                  replicaset={replicaset}
                  consoleServer={consoleServer}
                  editReplicaset={editReplicaset}
                  joinServer={joinServer}
                  expellServer={expellServer}
                  createReplicaset={createReplicaset} />
              </div>
            );
          })}
        </div>
      </div>
    );
  }
}

ReplicasetList.propTypes = {
  clusterSelf: PropTypes.any,
  dataSource: PropTypes.arrayOf(PropTypes.shape({
    uuid: PropTypes.string,
  })).isRequired,
  consoleServer: PropTypes.func.isRequired,
  editReplicaset: PropTypes.func.isRequired,
  joinServer: PropTypes.func.isRequired,
  expellServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
};

export default ReplicasetList;
