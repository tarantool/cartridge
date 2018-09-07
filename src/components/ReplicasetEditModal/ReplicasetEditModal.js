import PropTypes from 'prop-types';
import React from 'react';

import CommonItemEditModal from 'src/components/CommonItemEditModal';

import './ReplicasetEditModal.css';

const fields = [
  {
    key: 'uuid',
    hidden: true,
  },
  {
    key: 'roles',
    title: 'Roles',
    type: 'checkboxGroup',
    options: [
      {
        key: 't-connect',
        label: 't-connect',
      },
      {
        key: 'ib-core',
        label: 'ib-core',
      },
      {
        key: 'storage',
        label: 'storage',
      },
      {
        key: 'logger',
        label: 'logger',
      },
      {
        key: 'notifier',
        label: 'notifier',
      }
    ],
  },
];

const getReplicasetDefaultDataSource = () => {
  return {
    uuid: null,
    roles: [],
  };
};

class ReplicasetEditModal extends React.PureComponent {
  render() {
    const { isLoading, isSaving, replicasetNotFound, shouldCreateReplicaset, replicaset, submitStatusMessage, onSubmit,
      onRequestClose } = this.props;

    const dataSource = isLoading
      ? null
      : shouldCreateReplicaset ? getReplicasetDefaultDataSource() : replicaset;

    return (
      <CommonItemEditModal
        title={['Create replicaset', 'Edit replicaset']}
        isLoading={isLoading}
        isSaving={isSaving}
        itemNotFound={replicasetNotFound}
        shouldCreateItem={shouldCreateReplicaset}
        fields={fields}
        dataSource={dataSource}
        submitStatusMessage={submitStatusMessage}
        onSubmit={onSubmit}
        onRequestClose={onRequestClose} />
    );
  }
}

ReplicasetEditModal.propTypes = {
  isLoading: PropTypes.bool,
  isSaving: PropTypes.bool,
  replicasetNotFound: PropTypes.bool,
  shouldCreateReplicaset: PropTypes.bool,
  replicaset: PropTypes.shape({
    uuid: PropTypes.string,
    roles: PropTypes.arrayOf(PropTypes.string).isRequired,
  }),
  submitStatusMessage: PropTypes.string,
  onSubmit: PropTypes.func.isRequired,
  onRequestClose: PropTypes.func.isRequired,
};

ReplicasetEditModal.defaultProps = {
  isLoading: false,
  isSaving: false,
  replicasetNotFound: false,
  shouldCreateReplicaset: false,
};

export default ReplicasetEditModal;
