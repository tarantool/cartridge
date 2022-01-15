// @flow
import React from 'react';
import { Field, Form, FormSpy } from 'react-final-form';
import { css } from '@emotion/css';
import { uniq } from 'ramda';
import { useCore } from '@tarantool.io/frontend-core';
import { Button, Checkbox, FormField, LabeledInput, PopupFooter, RadioButton } from '@tarantool.io/ui-kit';

import SelectedServersList from 'src/components/SelectedServersList';
import type { Replicaset, Role, Server, VshardGroup } from 'src/generated/graphql-typing';
import {
  getDependenciesString,
  getRolesDependencies,
  isVShardGroupInputDisabled,
  validateForm,
} from 'src/misc/replicasetFormFunctions';
import type { CreateReplicasetArgs } from 'src/store/request/clusterPage.requests';

const styles = {
  wrap: css`
    display: flex;
    flex-wrap: wrap;
    width: calc(100% + 32px);
    margin-left: -16px;
    margin-right: -16px;
  `,
  weightInput: css`
    width: 97px;
  `,
  splash: css`
    flex-basis: 100%;
    max-width: 100%;
  `,
  wideField: css`
    flex-basis: 100%;
    max-width: 100%;
    margin-left: 16px;
    margin-right: 16px;
  `,
  field: css`
    flex-basis: calc(33.33% - 32px);
    margin-left: 16px;
    margin-right: 16px;
  `,
  doubleField: css`
    flex-basis: calc(66% - 32px);
    flex-grow: 1;
    margin-left: 16px;
    margin-right: 16px;
  `,
};

const vshardTooltipInfo = (
  <span>
    Group choice is available only if the role &quot;<b>vshard-storage</b> is enabled&quot;
  </span>
);
const allRwTooltipInfo = 'If disabled, only the leader of the replica set is writeable';

const initialValues = {
  alias: '',
  all_rw: false,
  roles: [],
  vshard_group: null,
  weight: null,
};

type CreateReplicasetFormProps = {
  selfURI?: string,
  knownRoles?: Role[],
  onCancel: () => void,
  onSubmit: (d: CreateReplicasetArgs) => void,
  replicasetList?: Replicaset[],
  selectedServers?: Server[],
  storageRolesNames: string[],
  vshard_groups?: VshardGroup[],
};

const CreateReplicasetForm = ({
  selfURI,
  knownRoles,
  onCancel,
  onSubmit,
  vshard_groups,
  // replicasetList,
  selectedServers,
  storageRolesNames,
}: CreateReplicasetFormProps) => {
  const core = useCore();
  return (
    <Form
      initialValues={initialValues}
      keepDirtyOnReinitialize
      validate={validateForm}
      onSubmit={(values) => {
        onSubmit({
          ...values,
          alias: values.alias || null,
          uri: (selectedServers && selectedServers[0] && selectedServers[0].uri) || '',
          weight: parseFloat(values.weight),
        });
      }}
    >
      {({ errors = {}, form, handleSubmit, initialValues, values = {} }) => {
        const activeDependencies = getRolesDependencies(values.roles, knownRoles);
        const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles);
        const rolesColumns = knownRoles && knownRoles.length > 6 ? 3 : 2;
        const { cartridge_hide_all_rw } = core.variables;

        return (
          <form onSubmit={handleSubmit}>
            <SelectedServersList className={styles.splash} serverList={selectedServers} selfURI={selfURI} />
            <div className={styles.wrap}>
              <FormSpy
                subscription={{ values: true }}
                onChange={({ values }) => {
                  if (!values) return;
                  const vshardStorageRoleChecked = values.roles.some((role) => storageRolesNames.includes(role));

                  if (!vshardStorageRoleChecked && typeof values.weight === 'string') {
                    form.change('weight', initialValues && initialValues.weight);
                  }

                  if (vshard_groups && vshard_groups.length === 1) {
                    if (vshardStorageRoleChecked && !values.vshard_group) {
                      form.change('vshard_group', vshard_groups[0].name);
                    }

                    if (!vshardStorageRoleChecked && values.vshard_group) {
                      form.change('vshard_group', null);
                    }
                  }
                }}
              />
              <Field name="alias">
                {({ input: { name, value, onChange }, meta: { error } }) => (
                  <LabeledInput
                    className={styles.field}
                    label="Replica set name"
                    name={name}
                    onChange={onChange}
                    value={value}
                    error={!!error}
                    message={error}
                    autoFocus
                  />
                )}
              </Field>
              <Field name="roles">
                {({ input: { name: fieldName, value } }) => (
                  <FormField
                    className={styles.wideField}
                    columns={rolesColumns}
                    label="Roles"
                    subTitle={
                      <Button
                        intent="plain"
                        onClick={() => {
                          form.change(
                            fieldName,
                            !knownRoles || value.length === knownRoles.length ? [] : knownRoles.map(({ name }) => name)
                          );
                        }}
                        size="xs"
                        text={value.length === (knownRoles && knownRoles.length) ? 'Deselect all' : 'Select all'}
                      />
                    }
                    verticalSort
                  >
                    {knownRoles &&
                      knownRoles.reduceRight((acc, { name, dependencies }) => {
                        acc.push(
                          <Checkbox
                            onChange={() => {
                              const activeRoles = value.includes(name)
                                ? value.filter((x) => x !== name)
                                : value.concat([name]);

                              const prevDependencies = getRolesDependencies(value, knownRoles);
                              const rolesWithoutDependencies = activeRoles.filter(
                                (role) => !prevDependencies.includes(role)
                              );
                              const newDependencies = getRolesDependencies(rolesWithoutDependencies, knownRoles);

                              form.change(fieldName, uniq([...newDependencies, ...rolesWithoutDependencies]));
                            }}
                            name={fieldName}
                            value={name}
                            checked={value.includes(name)}
                            disabled={activeDependencies.includes(name)}
                          >
                            {`${name}${getDependenciesString(dependencies)}`}
                          </Checkbox>
                        );
                        return acc;
                      }, [])}
                  </FormField>
                )}
              </Field>
              <Field name="weight">
                {({ input: { name, value, onChange }, meta: { error } }) => (
                  <LabeledInput
                    className={styles.field}
                    label="Replica set weight"
                    inputClassName={styles.weightInput}
                    name={name}
                    error={error}
                    value={value}
                    onChange={onChange}
                    disabled={!values.roles.some((role) => storageRolesNames.includes(role))}
                    placeholder="Auto"
                    message={error}
                  />
                )}
              </Field>
              <Field name="vshard_group">
                {({ input: { name: fieldName, value, onChange } }) => (
                  <FormField className={styles.field} label="Vshard group" info={vshardTooltipInfo}>
                    {vshard_groups &&
                      vshard_groups.map(({ name }, index) => (
                        <RadioButton
                          key={index}
                          onChange={onChange}
                          name={fieldName}
                          value={name}
                          checked={name === value}
                          disabled={VShardGroupInputDisabled}
                        >
                          {name}
                        </RadioButton>
                      ))}
                  </FormField>
                )}
              </Field>
              {cartridge_hide_all_rw !== true && (
                <Field name="all_rw">
                  {({ input: { name: fieldName, value, onChange } }) => (
                    <FormField className={styles.field} label="All writable" info={allRwTooltipInfo}>
                      <Checkbox onChange={onChange} name={fieldName} checked={value}>
                        Make all instances writeable
                      </Checkbox>
                    </FormField>
                  )}
                </Field>
              )}
            </div>
            <PopupFooter
              controls={[
                <Button key="Cancel" type="button" onClick={onCancel} size="l">
                  Cancel
                </Button>,
                <Button
                  key="Create"
                  className="meta-test__CreateReplicaSetBtn"
                  intent="primary"
                  type="submit"
                  disabled={Object.keys(errors).length > 0}
                  size="l"
                >
                  Create replica set
                </Button>,
              ]}
            />
          </form>
        );
      }}
    </Form>
  );
};

export default CreateReplicasetForm;
