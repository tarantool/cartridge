// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import Modal from 'src/components/Modal';
import EditReplicasetForm from 'src/components/EditReplicasetForm';
import ReplicasetEditModal from 'src/components/ReplicasetEditModal';
import { addSearchParams } from 'src/misc/url';
import type {
  Role,
  Replicaset,
  VshardGroup
} from 'src/generated/graphql-typing';
import { editReplicaset } from 'src/store/actions/clusterPage.actions';

const styles = {
  tabContent: css`
    padding: 16px 0 0;
  `

}

type EditReplicasetModalProps = {
  editReplicaset: () => void,
  knownRoles?: Role[],
  loading?:? boolean,
  vshard_groups?: VshardGroup[],
  selectedReplicasetUuid?: string,
  replicasetList?: Replicaset[],
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

    const selectedReplicaset = replicasetList.find(({ uuid }) => selectedReplicasetUuid === uuid);

    return (
      <Modal
        title='Edit replica set'
        visible={!!selectedReplicasetUuid}
        loading={loading}
        onClose={this.handleClose}
        wide
      >
        <EditReplicasetForm
          replicaset={selectedReplicaset}
          vshard_groups={vshard_groups}
          knownRoles={knownRoles}
          onSubmit={this.handleEditReplicasetSubmit}
          onCancel={this.handleClose}
          loading={loading}
        />
        <ReplicasetEditModal
          isLoading={loading}
          replicasetNotFound={loading ? null : !selectedReplicaset}
          replicaset={selectedReplicaset}
        />
      </Modal>
    );
  }

  handleEditReplicasetSubmit = (formData: CreateReplicasetMutationVariables) => {
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
