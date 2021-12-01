// @flow
import React from 'react';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import { Modal } from '@tarantool.io/ui-kit';

import EditReplicasetForm from 'src/components/EditReplicasetForm';
import type { Replicaset, Role, VshardGroup } from 'src/generated/graphql-typing';
import { addSearchParams } from 'src/misc/url';
import { editReplicaset } from 'src/store/actions/clusterPage.actions';
import type { EditReplicasetArgs } from 'src/store/request/clusterPage.requests';
import { selectVshardRolesNames } from 'src/store/selectors/clusterPage';

type EditReplicasetModalProps = {
  editReplicaset: Function,
  knownRoles?: Role[],
  loading?: ?boolean,
  vshard_groups?: VshardGroup[],
  selectedReplicasetUuid?: string,
  storageRolesNames: string[],
  replicasetList?: Replicaset[],
  history: History,
  location: Location,
  selfURI?: string,
  failoverMode?: string,
};

class EditReplicasetModal extends React.Component<EditReplicasetModalProps> {
  render() {
    const {
      knownRoles,
      loading,
      failoverMode,
      vshard_groups,
      replicasetList,
      selectedReplicasetUuid,
      selfURI,
      storageRolesNames,
    } = this.props;

    const selectedReplicaset =
      (replicasetList && replicasetList.find(({ uuid }) => selectedReplicasetUuid === uuid)) || null;

    return (
      <Modal
        className="meta-test__EditReplicasetModal"
        title="Edit replica set"
        visible={!!selectedReplicasetUuid}
        loading={loading}
        onClose={this.handleClose}
        wide
      >
        {selectedReplicaset && (
          <EditReplicasetForm
            replicaset={selectedReplicaset}
            vshard_groups={vshard_groups}
            knownRoles={knownRoles}
            onSubmit={this.handleEditReplicasetSubmit}
            onCancel={this.handleClose}
            loading={!!loading}
            selfURI={selfURI}
            storageRolesNames={storageRolesNames}
            failoverMode={failoverMode}
          />
        )}
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
      search: addSearchParams(location.search, { r: null }),
    });
  };
}

const mapStateToProps = (state) => {
  const {
    app: {
      clusterSelf: { knownRoles, vshard_groups, uri: selfURI },
      failover_params: { mode: failoverMode },
    },
    clusterPage: { pageDataRequestStatus, replicasetList, selectedReplicasetUuid },
  } = state;

  return {
    knownRoles,
    vshard_groups,
    replicasetList,
    selectedReplicasetUuid,
    selfURI,
    storageRolesNames: selectVshardRolesNames(state).storage,
    loading: !pageDataRequestStatus.loaded || pageDataRequestStatus.loading,
    failoverMode,
  };
};

const mapDispatchToProps = {
  editReplicaset,
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(EditReplicasetModal));
