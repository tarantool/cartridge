import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import CommonItemEditModal from 'src/components/CommonItemEditModal';

import './ReplicasetEditModal.css';

const isStorageWeightInputDisabled = formData => ! formData.roles.includes('vshard-storage');
const isStorageWeightInputValueValid = formData => {
  // return /^[0-9]*(\.[0-9]+)?$/.test(formData.weight.trim());
  const number = Number(formData.weight);
  return number >= 0 && number < Infinity;
};

const prepareFields = roles => {
  const rolesOptions = roles.map(role => ({ key: role, label: role }));

  return [
    {
      key: 'uuid',
      hidden: true,
    },
    {
      key: 'roles',
      title: 'Roles',
      type: 'checkboxGroup',
      options: rolesOptions,
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
    {
      key: 'weight',
      title: 'Weight',
      type: 'input',
      disabled: isStorageWeightInputDisabled,
      customProps: {
        create: {
          hidden: true,
        },
      },
      invalid: dataSource => {
        return ! isStorageWeightInputDisabled(dataSource)
          && dataSource.weight != null
          && dataSource.weight.trim() !== ''
          && ! isStorageWeightInputValueValid(dataSource);
      },
      invalidFeedback: 'Field accepts number, ex: 1.2',
    },
  ];
};

const defaultDataSource =  {
  uuid: null,
  roles: [],
  weight: '',
  master: null,
  servers: [],
};

const prepareDataSource = replicaset => {
  return {
    ...replicaset,
    weight: replicaset.weight != null ? String(replicaset.weight) : '',
    master: replicaset.master.uuid,
  };
};

class ReplicasetEditModal extends React.PureComponent {
  render() {
    const { isLoading, isSaving, replicasetNotFound, shouldCreateReplicaset, submitStatusMessage, onSubmit,
      onRequestClose } = this.props;

    const dataSource = isLoading || replicasetNotFound
      ? null
      : shouldCreateReplicaset ? defaultDataSource : this.getDataSource();
    const fields = this.getFields();

    return (
      <CommonItemEditModal
        title={['Create replica set', 'Edit replica set']}
        isLoading={isLoading}
        isSaving={isSaving}
        itemNotFound={replicasetNotFound}
        shouldCreateItem={shouldCreateReplicaset}
        fields={fields}
        dataSource={dataSource}
        isFormReadyToSubmit={this.isFormReadyToSubmit}
        submitStatusMessage={submitStatusMessage}
        onSubmit={onSubmit}
        onRequestClose={onRequestClose} />
    );
  }

  isFormReadyToSubmit = formData => {
    if ( ! isStorageWeightInputDisabled(formData)) {
      return isStorageWeightInputValueValid(formData);
    }
    return true;
  };

  getFields = () => {
    const { knownRoles } = this.props;
    return this.prepareFields(knownRoles);
  };

  getDataSource = () => {
    const { replicaset } = this.props;
    return this.prepareDataSource(replicaset);
  };

  prepareFields = defaultMemoize(prepareFields);

  prepareDataSource = defaultMemoize(prepareDataSource);
}

ReplicasetEditModal.propTypes = {
  isLoading: PropTypes.bool,
  isSaving: PropTypes.bool,
  replicasetNotFound: PropTypes.bool,
  shouldCreateReplicaset: PropTypes.bool,
  knownRoles: PropTypes.arrayOf(PropTypes.string).isRequired,
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
