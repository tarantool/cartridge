// @flow
import * as R from 'ramda';
import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import {css} from 'react-emotion';
import { DEFAULT_VSHARD_GROUP_NAME } from 'src/constants';
import CommonItemEditModal from 'src/components/CommonItemEditModal';
import './ReplicasetEditModal.css';

const styles = {
  uriLabel: css`
    color: #838383;
  `,
  serverLabel: css`
    font-size: 14px;
    color: #343434;
    font-family: Roboto;
  `,
  dragIcon: css`
    width: 100%;
    cursor: move!important;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: lightgrey;
    font-size: 20px;
  `,
  tableStyles: css`
    margin-left: 0px;
  `
};


const isStorageWeightInputDisabled = formData => ! formData.roles.includes('vshard-storage');
const isStorageWeightInputValueValid = formData => {
  // return /^[0-9]*(\.[0-9]+)?$/.test(formData.weight.trim());
  const number = Number(formData.weight);
  return number >= 0 && number < Infinity;
};

const renderSelectOptions = record => record.servers.map(server => ({
  key: server.uuid,
  label: <span className={styles.serverLabel}>
            {server.alias || 'No alias'}{' '}
    <span className={styles.uriLabel}>{server.uri}</span>
          </span>,
}));

const renderDraggableListOptions = record => record.servers.map(server => ({
  key: server.uuid,
  label: <span className={styles.serverLabel}>
            {server.alias || 'No alias'}{' '}
    <span className={styles.uriLabel}>{server.uri}</span>
          </span>,
}));

const getRolesDependencies = (activeRoles, rolesOptions) => {
  const result = [];
  rolesOptions.forEach(({ key, dependencies }) => {
    if (activeRoles.includes(key)) {
      result.push(...dependencies);
    }
  });
  return R.uniq(result);
};

const prepareFields = (roles, replicaset, vshardGroups) => {
  const rolesOptions = roles.map(
    ({
      name,
      dependencies = []
    }) => {
      const dependenciesLabel = dependencies.length > 3
        ? ` (+ ${dependencies.slice(0, 2).join(', ')}, ${dependencies.length - 2} more)`
        : ` (+ ${dependencies.join(', ')})`;

      const label = (
        <React.Fragment>
          {name}
          {!!dependencies.length && (
            <span style={{ color: 'gray' }}>
              {dependenciesLabel}
            </span>
          )}
        </React.Fragment>
      );

      return {
        key: name,
        label,
        dependencies
      };
    }
  );

  const implementVShardGroups = vshardGroups.length > 1 || vshardGroups[0] !== DEFAULT_VSHARD_GROUP_NAME;

  let vshardGroupsOptions = implementVShardGroups
    ? vshardGroups.map(group => ({ key: group, label: group, }))
    : [];

  const shallRenderDraggableList = replicaset && replicaset.servers.length > 2;

  const draggableListCustomProps = {};

  if (!shallRenderDraggableList) {
    draggableListCustomProps.create = {
      hidden: true,
    };
  } else {
    draggableListCustomProps.create = {
      tableProps: {
        showHeader: false,
        className: styles.tableStyles,
        rowKey: 'uuid',
      },
      tableColumns: [
        {
          title: 'Operates',
          key: 'operate',
          render: () => <a className={styles.dragIcon}>☰</a>,
          width: 50,
        },

        {
          title: 'Альяс',
          dataIndex: 'alias',
        },
        {
          title: 'Адрес',
          dataIndex: 'uri',
        },
      ],
      tableData: R.pipe(
          R.map(R.pick(['alias', 'uri', 'uuid'])),
          R.map((data) => ({ ...data, key: data.uuid })),
      )(replicaset.servers)
    };
    draggableListCustomProps.edit = draggableListCustomProps.create;
  }

  return [
    {
      key: 'uuid',
      hidden: true,
    },
    {
      key: 'roles',
      title: 'Roles',
      type: 'checkboxGroup',
      options: ({ roles }) => {
        const dependencies = getRolesDependencies(roles, rolesOptions);
        return rolesOptions
          .reduceRight((acc, option) => (acc.push({
            ...option,
            disabled: dependencies.includes(option.key)
          }) && acc), []);
      },
      stateModifier: (prevState, { roles, ...formData }) => {
        const prevDependencies = getRolesDependencies(prevState.roles, rolesOptions);
        const rolesWithoutDependencies = roles.filter(role => !prevDependencies.includes(role)) 
        const dependencies = getRolesDependencies(rolesWithoutDependencies, rolesOptions);

        return {
          ...formData,
          roles: R.uniq([...dependencies, ...rolesWithoutDependencies])
        };
      }
    },
    ...implementVShardGroups
      ? [{
        key: 'vshard_group',
        title: 'Group',
        type: 'optionGroup',
        disabled: isStorageWeightInputDisabled,
        options: vshardGroupsOptions,
      }]
      : [],
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
    {
      key: 'master',
      title: shallRenderDraggableList ? 'Priority' : 'Master',
      type: shallRenderDraggableList ? 'draggableList' : 'optionGroup',
      options: shallRenderDraggableList ? renderDraggableListOptions : renderSelectOptions,
      customProps: draggableListCustomProps,
    }
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
        onRequestClose={onRequestClose}
      />
    );
  }

  isFormReadyToSubmit = formData => {
    if ( ! isStorageWeightInputDisabled(formData)) {
      return isStorageWeightInputValueValid(formData);
    }
    return true;
  };

  getFields = () => {
    const { knownRoles, replicaset, vshard_known_groups } = this.props;
    return this.prepareFields(knownRoles, replicaset, vshard_known_groups);
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
    roles: PropTypes.arrayOf(PropTypes.shape({
      name: PropTypes.string.isRequired,
      dependencies: PropTypes.arrayOf(PropTypes.string)
    })).isRequired,
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
