// @flow
import * as R from 'ramda';
import React from 'react';
import { defaultMemoize } from 'reselect';
import {css} from 'react-emotion';
import { DEFAULT_VSHARD_GROUP_NAME, VSHARD_STORAGE_ROLE_NAME } from 'src/constants';
import CommonItemEditModal from 'src/components/CommonItemEditModal';
import type { Replicaset, Role, VshardGroup } from 'src/generated/graphql-typing';
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
  `,
  roleDependencies: css`
    color: gray;
  `
};

/**
 * @param {Object} formData
 * @param {Object} replicaset
 */
const isVShardGroupInputDisabled = (
  { roles }: Replicaset,
  { vshard_group }: Replicaset = {}
): boolean => !(roles || []).includes(VSHARD_STORAGE_ROLE_NAME) || !!vshard_group;

const isStorageWeightInputDisabled = ({ roles }: Replicaset): boolean => (
  !(roles || []).includes(VSHARD_STORAGE_ROLE_NAME)
);

const isStorageWeightInputValueValid = (formData: Replicaset): boolean => {
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

const getDependenciesString = (dependencies: string[]) => {
  return dependencies.length > 3
    ? ` (+ ${dependencies.slice(0, 2).join(', ')}, ${dependencies.length - 2} more)`
    : ` (+ ${dependencies.join(', ')})`;
};

const prepareFields = (roles: Role[], replicaset: ?Replicaset, vshardGroups: ?VshardGroup[]) => {
  const rolesOptions = roles.map(
    ({
      name,
      dependencies
    }) => {
      const label = (
        <React.Fragment>
          {name}
          {!!(dependencies && dependencies.length) && (
            <span className={styles.roleDependencies}>
              {getDependenciesString(dependencies)}
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

  let vshardGroupsOptions = vshardGroups
    ? vshardGroups.map(({ name }) => ({ key: name, label: name, }))
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
    ...vshardGroups
      ? [{
        key: 'vshard_group',
        title: 'Group',
        type: 'optionGroup',
        disabled: formData => isVShardGroupInputDisabled(formData, replicaset),
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

type ReplicasetEditModalProps = {
  isLoading?: boolean,
  isSaving?: boolean,
  replicasetNotFound?: boolean,
  shouldCreateReplicaset?: boolean,
  knownRoles: string[],
  vshard_groups: ?VshardGroup[],
  replicaset: Replicaset,
  submitStatusMessage?: string,
  onSubmit: () => void,
  onRequestClose: () => void
};

class ReplicasetEditModal extends React.PureComponent<ReplicasetEditModalProps> {
  static defaultProps = {
    isLoading: false,
    isSaving: false,
    replicasetNotFound: false,
    shouldCreateReplicaset: false,
  };

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

  isVShardGroupsImplemented = () => {
    const { vshard_groups } = this.props;
    return vshard_groups && (vshard_groups.length > 1 || vshard_groups[0].name !== DEFAULT_VSHARD_GROUP_NAME);
  }


  isFormReadyToSubmit = (formData: Replicaset): boolean => {
    const isWeightValid = isStorageWeightInputDisabled(formData) || isStorageWeightInputValueValid(formData);
    const isGroupValid = isVShardGroupInputDisabled(formData, this.props.replicaset) || !!formData.vshard_group;
    return isWeightValid && (isGroupValid || !this.isVShardGroupsImplemented());
  };

  getFields = () => {
    const { knownRoles, replicaset, vshard_groups } = this.props;
    return this.prepareFields(knownRoles, replicaset, this.isVShardGroupsImplemented() ? vshard_groups : null);
  };

  getDataSource = () => {
    const { replicaset } = this.props;
    return this.prepareDataSource(replicaset);
  };

  prepareFields = defaultMemoize(prepareFields);

  prepareDataSource = defaultMemoize(prepareDataSource);
}

export default ReplicasetEditModal;
