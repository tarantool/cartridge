// @flow
import React from 'react';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import { Modal } from '@tarantool.io/ui-kit';
import EditReplicasetForm from 'src/components/EditReplicasetForm';
import { addSearchParams } from 'src/misc/url';
import type {
  Role,
  Replicaset,
  VshardGroup
} from 'src/generated/graphql-typing';
import { editReplicaset } from 'src/store/actions/clusterPage.actions';
import type { EditReplicasetArgs } from 'src/store/request/clusterPage.requests';

type EditReplicasetModalProps = {
  editReplicaset: Function,
  knownRoles?: Role[],
  loading?:? boolean,
  vshard_groups?: VshardGroup[],
  selectedReplicasetUuid?: string,
  replicasetList?: Replicaset[],
  history: History,
  location: Location,
  selfURI?: string
}

class EditReplicasetModal extends React.Component<EditReplicasetModalProps> {
  render() {
    const {
      knownRoles,
      loading,
      vshard_groups,
      replicasetList,
      selectedReplicasetUuid,
      selfURI
    } = this.props;

    const selectedReplicaset = (
      replicasetList && replicasetList.find(({ uuid }) => selectedReplicasetUuid === uuid)
    ) || null;

    return (
      <Modal
        className='meta-test__EditReplicasetModal'
        title='Edit replica set'
        visible={!!selectedReplicasetUuid}
        loading={loading}
        onClose={this.handleClose}
        thinBorders
        wide
      >
        {
          selectedReplicaset
          &&
          <EditReplicasetForm
            replicaset={selectedReplicaset}
            vshard_groups={vshard_groups}
            knownRoles={knownRoles}
            onSubmit={this.handleEditReplicasetSubmit}
            onCancel={this.handleClose}
            loading={!!loading}
            selfURI={selfURI}
          />
        }
      </Modal>
    );
  }

  handleEditReplicasetSubmit = (formData: EditReplicasetArgs) => {
    this.props.editReplicaset(formData);
    this.handleClose();
  };

  handleClose = () => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { r: null })
    });
  }
};

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf: {
        knownRoles,
        vshard_groups,
        uri: selfURI
      }
    },
    clusterPage: {
      pageDataRequestStatus,
      replicasetList,
      selectedReplicasetUuid
    }
  } = state;

  return {
    knownRoles,
    vshard_groups,
    replicasetList,
    selectedReplicasetUuid,
    selfURI,
    loading: !pageDataRequestStatus.loaded || pageDataRequestStatus.loading
  };
};

const mapDispatchToProps = {
  editReplicaset
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(EditReplicasetModal));
