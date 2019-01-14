import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import ReplicasetCard from 'src/components/ReplicasetCard';

import './ReplicasetList.css';

const prepareReplicasetList = dataSource => [...dataSource].sort((a, b) => b.uuid < a.uuid ? 1 : -1);

class ReplicasetList extends React.PureComponent {
  prepareReplicasetList = defaultMemoize(prepareReplicasetList);

  render() {
    const { clusterSelf, consoleServer, editReplicaset, joinServer, expellServer, createReplicaset } = this.props;

    const replicasetList = this.getReplicasetList();

    return (
      <div className="ReplicasetList-outer">
        <div className="ReplicasetList-inner">
          {replicasetList.map(replicaset => {
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

  getReplicasetList = () => {
    const { dataSource } = this.props;
    return this.prepareReplicasetList(dataSource);
  };
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
