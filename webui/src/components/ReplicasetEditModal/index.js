import { connect } from 'react-redux';

import ReplicasetEditModal from './ReplicasetEditModal';

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf: {
        knownRoles,
      },
    },
  } = state;

  return {
    knownRoles,
  };
};

export default connect(mapStateToProps)(ReplicasetEditModal);
