import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import ReplicasetCard from 'src/components/ReplicasetCard';

import './ReplicasetList.css';

const prepareReplicasetList = dataSource => [...dataSource].sort((a, b) => b.uuid < a.uuid ? 1 : -1);

class ReplicasetList extends React.PureComponent {
  prepareReplicasetList = defaultMemoize(prepareReplicasetList);

  render() {
    const {
      clusterSelf,
      editReplicaset,
      joinServer,
      expelServer,
      createReplicaset,
      onServerLabelClick
    } = this.props;

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
                  editReplicaset={editReplicaset}
                  joinServer={joinServer}
                  expelServer={expelServer}
                  createReplicaset={createReplicaset}
                  onServerLabelClick={onServerLabelClick}
                />
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
  editReplicaset: PropTypes.func.isRequired,
  joinServer: PropTypes.func.isRequired,
  expelServer: PropTypes.func.isRequired,
  createReplicaset: PropTypes.func.isRequired,
  onServerLabelClick: PropTypes.func
};

export default ReplicasetList;
