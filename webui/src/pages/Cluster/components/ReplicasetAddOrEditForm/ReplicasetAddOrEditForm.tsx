/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { Button, Checkbox, FormField, LabeledInput, Modal, RadioButton } from '@tarantool.io/ui-kit';

import ServerSortableList from 'src/components/ServerSortableList';
import { GetClusterRole, Maybe, ServerListReplicasetServer, app } from 'src/models';

import {
  WithReplicasetAddOrEditFormWithFormikProps,
  withReplicasetAddOrEditForm,
} from './ReplicasetAddOrEditForm.form';

import { styles } from './ReplicasetAddOrEditForm.styles';

const { uniq, map, compose, groupBy } = app.utils;

type ReplicasetConfigureModalFormProps = WithReplicasetAddOrEditFormWithFormikProps;

const getDependenciesString = (dependencies?: Maybe<string[]>) => {
  if (!dependencies || dependencies.length === 0) return '';

  return dependencies.length > 3
    ? ` (+ ${dependencies.slice(0, 2).join(', ')}, ${dependencies.length - 2} more)`
    : ` (+ ${dependencies.join(', ')})`;
};

const getRolesDependencies = (activeRoles: string[], roles: GetClusterRole[]) => {
  const result = roles.reduce((acc, { name, dependencies }) => {
    if (activeRoles.includes(name) && dependencies) {
      acc.push(...dependencies);
    }
    return acc;
  }, [] as string[]);

  return uniq(result);
};

// TODO: ??
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const serverMapCompose: (servers: ServerListReplicasetServer[]) => any = compose(
  map(([val]) => val),
  groupBy(({ uuid }: ServerListReplicasetServer) => uuid)
);

const ReplicasetAddOrEditForm = ({
  handleSubmit,
  handleReset,
  handleChange,
  setFieldValue,
  values,
  errors,
  touched,
  replicaset,
  knownRolesNames,
  clusterSelfUri,
  knownRoles,
  vshardGroupsNames,
  failoverParamsMode,
  pending,
  onClose,
}: ReplicasetConfigureModalFormProps) => {
  const isStorageRoleSelected = useMemo(
    () => values.roles.some((role) => knownRolesNames.storage.includes(role)),
    [values.roles, knownRolesNames.storage]
  );

  const rolesColumns = knownRoles.length > 6 ? 3 : 2;

  const handleFailoverPriorityChange = useCallback(
    (value: string[]) => {
      setFieldValue('failover_priority', value);
    },
    [setFieldValue]
  );

  const handleRoleCheck = useCallback(() => {
    setFieldValue('roles', knownRoles.length === values.roles.length ? [] : knownRoles.map(({ name }) => name));
  }, [setFieldValue, knownRoles, values.roles.length]);

  const activeDependencies = useMemo(() => getRolesDependencies(values.roles, knownRoles), [values.roles, knownRoles]);

  const isVShardGroupInputDisabled = useMemo(
    () => !values.roles.some((role) => knownRolesNames.storage.includes(role)) || !!replicaset?.vshard_group,
    [values.roles, knownRolesNames.storage, replicaset?.vshard_group]
  );

  const serverMap = useMemo(() => serverMapCompose(replicaset?.servers || []), [replicaset?.servers]);

  return (
    <form onSubmit={handleSubmit} onReset={handleReset} noValidate>
      <div className={styles.wrap}>
        <LabeledInput
          className={styles.field}
          label="Replica set name"
          name="alias"
          onChange={handleChange}
          value={values.alias}
          error={touched.alias && errors.alias}
          message={touched.alias && errors.alias}
          largeMargins
          autoFocus
        />
        <FormField
          className={styles.wideField}
          columns={rolesColumns}
          label="Roles"
          subTitle={
            <Button
              intent="plain"
              onClick={handleRoleCheck}
              size="xs"
              text={values.roles.length === knownRoles.length && knownRoles.length > 0 ? 'Deselect all' : 'Select all'}
            />
          }
          verticalSort
          largeMargins
        >
          {knownRoles.map(({ name, dependencies }) => (
            <Checkbox
              key={name}
              onChange={() => {
                const activeRoles = values.roles.includes(name)
                  ? values.roles.filter((x) => x !== name)
                  : values.roles.concat([name]);
                const rolesWithoutDependencies = activeRoles.filter((role) => !activeDependencies.includes(role));
                const newDependencies = getRolesDependencies(rolesWithoutDependencies, knownRoles);
                setFieldValue('roles', [...newDependencies, ...rolesWithoutDependencies]);
              }}
              name="roles"
              value={name}
              checked={values.roles.includes(name)}
              disabled={activeDependencies.includes(name)}
            >
              {`${name}${getDependenciesString(dependencies)}`}
            </Checkbox>
          ))}
        </FormField>
        <LabeledInput
          className={styles.field}
          label="Replica set weight"
          inputClassName={styles.weightInput}
          name="weight"
          error={touched.weight && errors.weight}
          message={touched.weight && errors.weight}
          value={values.weight}
          onChange={handleChange}
          disabled={!isStorageRoleSelected}
          placeholder="Auto"
          largeMargins
        />
        <FormField
          className={styles.field}
          label="Vshard group"
          info={
            <span>
              Group disabled not yet included the role of &quot;<b>vshard-storage</b>&quot;
            </span>
          }
          largeMargins
        >
          {vshardGroupsNames.map((name) => (
            <RadioButton
              key={name}
              onChange={handleChange}
              name="vshard_group"
              value={name}
              checked={name === values.vshard_group}
              disabled={isVShardGroupInputDisabled}
            >
              {name}
            </RadioButton>
          ))}
        </FormField>
        {app.variables.cartridge_hide_all_rw() && (
          <FormField
            className={styles.field}
            label="All writable"
            info="Otherwise only leader in the replicaset is writeable"
            largeMargins
          >
            <Checkbox name="all_rw" onChange={handleChange} checked={values.all_rw}>
              Make all instances writeable
            </Checkbox>
          </FormField>
        )}
        {replicaset && (
          <LabeledInput
            name="failover_priority"
            className={cx('ser', styles.wideField)}
            itemClassName={styles.radioWrap}
            label="Failover priority"
            inputComponent={ServerSortableList}
            value={values.failover_priority}
            onChange={handleFailoverPriorityChange}
            replicaset={replicaset}
            serverMap={serverMap}
            selfURI={clusterSelfUri}
            failoverMode={failoverParamsMode}
            largeMargins
          />
        )}
      </div>
      <Modal.Footer
        controls={[
          <Button key="Cancel" type="button" onClick={onClose} size="l" text="Cancel" />,
          <Button
            key="CreateOrEdit"
            className={replicaset ? 'meta-test__EditReplicasetSaveBtn' : 'meta-test__CreateReplicaSetBtn'}
            text={replicaset ? 'Save' : 'Create replica set'}
            intent="primary"
            type="submit"
            loading={pending}
            size="l"
          />,
        ]}
      />
    </form>
  );
};

export default withReplicasetAddOrEditForm(ReplicasetAddOrEditForm);
