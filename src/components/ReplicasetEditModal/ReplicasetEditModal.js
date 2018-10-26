import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

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
        key: 'vshard-router',
        label: 'vshard-router',
      },
      {
        key: 'vshard-storage',
        label: 'vshard-storage',
      },
    ],
  },
  {
    key: 'master',
    title: 'Master',
    type: 'optionGroup',
    options: record => {
      return record.servers.map(server => ({
        key: server.uuid,
        label: `${server.alias || 'No alias'} ${server.uri}`,
      }));
    },
    customProps: {
      create: {
        hidden: true,
      },
    },
  },
];

const defaultDataSource =  {
  uuid: null,
  roles: [],
  master: null,
  servers: [],
};

const prepareDataSource = replicaset => {
  return {
    ...replicaset,
    master: replicaset.master.uuid,
  };
};

class ReplicasetEditModal extends React.PureComponent {
  render() {
    const { isLoading, isSaving, replicasetNotFound, shouldCreateReplicaset, replicaset, submitStatusMessage, onSubmit,
      onRequestClose } = this.props;

    const dataSource = isLoading
      ? null
      : shouldCreateReplicaset ? defaultDataSource : this.getDataSource(replicaset);

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

  getDataSource = () => {
    const { replicaset } = this.props;
    return this.prepareDataSource(replicaset);
  };

  prepareDataSource = defaultMemoize(prepareDataSource);
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
