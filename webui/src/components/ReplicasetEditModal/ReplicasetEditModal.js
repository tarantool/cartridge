// @flow
import * as R from 'ramda';
import React from 'react';
import { defaultMemoize } from 'reselect';
import { css } from 'react-emotion';
import { DEFAULT_VSHARD_GROUP_NAME, VSHARD_STORAGE_ROLE_NAME } from 'src/constants';
import CommonItemEditForm from 'src/components/CommonItemEditForm';
import type {
  CreateReplicasetMutationVariables,
  MutationEdit_ReplicasetArgs,
  Replicaset,
  Role,
  Server,
  VshardGroup
} from 'src/generated/graphql-typing';
import type {
  CreateReplicasetActionCreator,
  EditReplicasetActionCreator
} from 'src/store/actions/clusterPage.actions';

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

type ReplicasetEditFormData = {
  ...$Exact<MutationEdit_ReplicasetArgs>,
  master: string,
  servers: Server[],
  weight: ?string
};

/**
 * @param {Object} formData
 * @param {Object} replicaset
 */
const isVShardGroupInputDisabled = (
  { roles }: Replicaset,
  replicaset: ?Replicaset
): boolean => !(roles || []).includes(VSHARD_STORAGE_ROLE_NAME) || !!(replicaset && replicaset.vshard_group);

const isStorageWeightInputDisabled = ({ roles }: Replicaset): boolean => (
  !(roles || []).includes(VSHARD_STORAGE_ROLE_NAME)
);

const isStorageWeightInputValueValid = (formData: Replicaset): boolean => {
  // return /^[0-9]*(\.[0-9]+)?$/.test(formData.weight.trim());
  const number = Number(formData.weight);
  return number >= 0 && number < Infinity;
};

const renderOptions = (record: ReplicasetEditFormData) => record.servers.map(server => ({
  key: server.uuid,
  label: (
    <span className={styles.serverLabel}>
      {server.alias || 'No alias'}{' '}
      <span className={styles.uriLabel}>{server.uri}</span>
    </span>
  )
}));

const getRolesDependencies = (activeRoles, rolesOptions) => {
  const result = [];
  rolesOptions.forEach(({ key, dependencies }) => {
    if (activeRoles.includes(key) && dependencies) {
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
    ? vshardGroups.map(({ name }) => ({ key: name, label: name }))
    : [];

  const shallRenderDraggableList = replicaset && replicaset.servers.length > 2;

  const draggableListCustomProps = {};

  if (!shallRenderDraggableList) {
    draggableListCustomProps.create = {
      hidden: true
    };
  } else {
    draggableListCustomProps.create = {
      tableProps: {
        showHeader: false,
        className: styles.tableStyles,
        rowKey: 'uuid'
      },
      tableColumns: [
        {
          title: 'Operates',
          key: 'operate',
          render: () => <a className={styles.dragIcon}>☰</a>,
          width: 50
        },
        {
          title: 'Альяс',
          dataIndex: 'alias'
        },
        {
          title: 'Адрес',
          dataIndex: 'uri'
        }
      ],
      tableData: R.pipe(
        R.map(R.pick(['alias', 'uri', 'uuid'])),
        R.map(data => ({ ...data, key: data.uuid })),
      )(replicaset && replicaset.servers)
    };
    draggableListCustomProps.edit = draggableListCustomProps.create;
  }

  return [
    {
      key: 'uuid',
      hidden: true
    },
    {
      key: 'roles',
      title: 'Roles',
      type: 'checkboxGroup',
      options: ({ roles }) => {
        const dependencies = getRolesDependencies(roles, rolesOptions);
        return rolesOptions.reduceRight((acc, option) => {
          acc.push({ ...option, disabled: dependencies.includes(option.key) });
          return acc;
        }, []);
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
        options: vshardGroupsOptions
      }]
      : [],
    {
      key: 'weight',
      title: 'Weight',
      type: 'input',
      disabled: isStorageWeightInputDisabled,
      customProps: {
        create: {
          hidden: true
        }
      },
      invalid: dataSource => {
        return ! isStorageWeightInputDisabled(dataSource)
          && dataSource.weight != null
          && dataSource.weight.trim() !== ''
          && ! isStorageWeightInputValueValid(dataSource);
      },
      invalidFeedback: 'Field accepts number, ex: 1.2'
    },
    {
      key: 'master',
      title: shallRenderDraggableList ? 'Priority' : 'Master',
      type: shallRenderDraggableList ? 'draggableList' : 'optionGroup',
      options: renderOptions,
      customProps: draggableListCustomProps,
      dataSource: 'servers',
      stateModifier: (prevState, nextState, fromIndex, toIndex) => {
        const servers = [...prevState.servers];
        const item = servers.splice(fromIndex, 1)[0];
        servers.splice(toIndex, 0, item);

        return {
          ...nextState,
          servers
        }
      }
    }
  ];
};

const defaultDataSource = {
  uuid: null,
  roles: [],
  weight: '',
  master: null,
  servers: []
};

const prepareDataSource = replicaset => {
  return {
    ...replicaset,
    weight: replicaset.weight != null ? String(replicaset.weight) : '',
    master: replicaset.master.uuid
  };
};

type ReplicasetEditModalProps = {
  createReplicasetModalDataSource: ?Server,
  isLoading?: boolean,
  isSaving?: boolean,
  replicasetNotFound?: boolean,
  shouldCreateReplicaset?: boolean,
  knownRoles: string[],
  vshard_groups: ?VshardGroup[],
  replicaset: Replicaset,
  submitStatusMessage?: string,
  onRequestClose: () => void,
  createReplicaset: CreateReplicasetActionCreator,
  editReplicaset: EditReplicasetActionCreator
};

class ReplicasetEditModal extends React.PureComponent<ReplicasetEditModalProps> {
  static defaultProps = {
    isLoading: false,
    isSaving: false,
    replicasetNotFound: false,
    shouldCreateReplicaset: false
  };

  render() {
    const {
      isLoading,
      isSaving,
      replicasetNotFound,
      shouldCreateReplicaset,
      submitStatusMessage,
      onRequestClose
    } = this.props;

    const dataSource = isLoading || replicasetNotFound
      ? null
      : shouldCreateReplicaset ? defaultDataSource : this.getDataSource();
    const fields = this.getFields();

    return (
      <CommonItemEditForm
        title={['Create replica set', 'Edit replica set']}
        isLoading={isLoading}
        isSaving={isSaving}
        itemNotFound={replicasetNotFound}
        shouldCreateItem={shouldCreateReplicaset}
        fields={fields}
        dataSource={dataSource}
        isFormReadyToSubmit={this.isFormReadyToSubmit}
        submitStatusMessage={submitStatusMessage}
        onSubmit={shouldCreateReplicaset ? this.handleCreateReplicasetSubmit : this.handleEditReplicasetSubmit}
        onRequestClose={onRequestClose}
      />
    );
  }

  handleCreateReplicasetSubmit = (replicaset: CreateReplicasetMutationVariables) => {
    const {
      createReplicaset,
      createReplicasetModalDataSource,
      onRequestClose
    } = this.props;

    createReplicaset({
      ...createReplicasetModalDataSource,
      roles: replicaset.roles,
      vshard_group: replicaset.vshard_group
    });

    onRequestClose();
  };

  handleEditReplicasetSubmit = ({
    uuid,
    roles,
    vshard_group,
    servers,
    weight,
    master,
    ...formData
  }:
ReplicasetEditFormData) => { // TODO: fix eslint issue https://github.com/babel/babel-eslint/issues/513
    const { editReplicaset, onRequestClose } = this.props;
    let mastersPriorityList: ?string[];

    if (servers.length === 2) {
      const secondaryMaster = servers
        .map(({ uuid }) => uuid)
        .find(uuid => uuid !== master);
      mastersPriorityList = [master, ...(secondaryMaster ? [secondaryMaster] : [])]
    } else {
      mastersPriorityList = servers.map(({ uuid }) => uuid);
    }

    onRequestClose();

    editReplicaset({
      uuid,
      roles,
      vshard_group,
      master: mastersPriorityList,
      weight: weight == null || weight.trim() === '' ? null : Number(weight)
    });
  };

  isVShardGroupsImplemented = () => {
    const { vshard_groups } = this.props;
    return vshard_groups && vshard_groups.length &&
      (vshard_groups.length > 1 || vshard_groups[0].name !== DEFAULT_VSHARD_GROUP_NAME);
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
