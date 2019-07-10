// @flow
import { connect } from 'react-redux';
import ReplicasetEditModal from './ReplicasetEditModal';

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf: {
        knownRoles,
        vshard_groups
      },
    },
  } = state;

  return {
    knownRoles,
    vshard_groups
  };
};

export default connect(mapStateToProps)(ReplicasetEditModal);
