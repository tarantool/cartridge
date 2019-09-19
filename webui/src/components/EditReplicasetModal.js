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
  VshardGroup,
  EditReplicasetMutationVariables
} from 'src/generated/graphql-typing';
import { editReplicaset } from 'src/store/actions/clusterPage.actions';

type EditReplicasetModalProps = {
  editReplicaset: Function,
  knownRoles?: Role[],
  loading?:? boolean,
  vshard_groups?: VshardGroup[],
  selectedReplicasetUuid?: string,
  replicasetList?: Replicaset[],
  history: History,
  location: Location,
}

class EditReplicasetModal extends React.Component<EditReplicasetModalProps> {
  render() {
    const {
      knownRoles,
      loading,
      vshard_groups,
      replicasetList,
      selectedReplicasetUuid
    } = this.props;

    const selectedReplicaset = (
      replicasetList && replicasetList.find(({ uuid }) => selectedReplicasetUuid === uuid)
    ) || null;

    return (
      <Modal
        title='Edit replica set'
        visible={!!selectedReplicasetUuid}
        loading={loading}
        onClose={this.handleClose}
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
          />
        }
      </Modal>
    );
  }

  handleEditReplicasetSubmit = (formData: EditReplicasetMutationVariables) => {
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
        vshard_groups
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
    loading: !pageDataRequestStatus.loaded || pageDataRequestStatus.loading
  };
};

const mapDispatchToProps = {
  editReplicaset
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(EditReplicasetModal));
