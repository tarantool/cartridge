// @flow
import { connect } from 'react-redux';
import ReplicasetEditModal from './ReplicasetEditModal';
import {
  createReplicaset,
  editReplicaset
} from 'src/store/actions/clusterPage.actions';

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf: {
        knownRoles,
        vshard_groups
      }
    }
  } = state;

  return {
    knownRoles,
    vshard_groups
  };
};

const mapDispatchToProps = {
  createReplicaset,
  editReplicaset
};

export default connect(mapStateToProps, mapDispatchToProps)(ReplicasetEditModal);
