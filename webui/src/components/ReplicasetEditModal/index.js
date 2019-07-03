import { connect } from 'react-redux';

import ReplicasetEditModal from './ReplicasetEditModal';

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf: {
        knownRoles,
        vshard_known_groups
      },
    },
  } = state;

  return {
    knownRoles,
    vshard_known_groups
  };
};

export default connect(mapStateToProps)(ReplicasetEditModal);
