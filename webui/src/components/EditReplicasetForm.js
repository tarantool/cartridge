// @flow
import React from 'react';
import { css, cx } from '@emotion/css';
import {
  compose,
  map,
  groupBy,
  prop,
  uniq
} from 'ramda';
import { Form, Field, FormSpy } from 'react-final-form';
import {
  Button,
  Checkbox,
  FormField,
  LabeledInput,
  PopupFooter,
  RadioButton
} from '@tarantool.io/ui-kit';
import SelectedReplicaset from 'src/components/SelectedReplicaset';
import type {
  Role,
  Replicaset,
  VshardGroup
} from 'src/generated/graphql-typing';
import type { EditReplicasetArgs } from 'src/store/request/clusterPage.requests';
import {
  getDependenciesString,
  getRolesDependencies,
  isVShardGroupInputDisabled,
  validateForm
} from 'src/misc/replicasetFormFunctions';
import ServerSortableList from './ServerSortableList';

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
  radioWrap: css`
    display: flex;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;

    &:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }
  `,
  splash: css`
    flex-basis: 100%;
    max-width: 100%;
  `,
  field: css`
    flex-basis: calc(33.33% - 32px);
    margin-left: 16px;
    margin-right: 16px;
  `,
  wideField: css`
    flex-basis: 100%;
    margin-left: 16px;
    margin-right: 16px;
  `,
  doubleField: css`
    flex-basis: calc(66% - 32px);
    flex-grow: 1;
    margin-left: 16px;
    margin-right: 16px;
  `
}

const vshardTooltipInfo = <span>Group disabled not yet included the role of "<b>vshard-storage</b>"</span>;
const allRwTooltipInfo = 'Otherwise only leader in the replicaset is writeable';

type EditReplicasetFormProps = {
  knownRoles?: Role[],
  loading?: boolean,
  onCancel: () => void,
  onSubmit: (d: EditReplicasetArgs) => void,
  replicaset?: Replicaset,
  vshard_groups?: VshardGroup[],
  selfURI?: string,
  storageRolesNames: string[]
};

const EditReplicasetForm = ({
  knownRoles,
  loading,
  onCancel,
  onSubmit,
  vshard_groups,
  replicaset,
  selfURI,
  storageRolesNames
}:
EditReplicasetFormProps) => {
  if (!replicaset) {
    return 'Replicaset not found';
  }

  return (
    <Form
      initialValues={{
        alias: replicaset.alias,
        all_rw: replicaset.all_rw,
        roles: replicaset.roles || [],
        vshard_group: replicaset.vshard_group,
        master: replicaset.servers.map(({ uuid }) => uuid),
        weight: replicaset.weight
      }}
      keepDirtyOnReinitialize
      validate={validateForm}
      onSubmit={values => {
        onSubmit({
          ...values,
          alias: values.alias || null,
          uuid: replicaset.uuid,
          weight: parseFloat(values.weight)
        });
      }}
    >
      {({
        errors = {},
        form,
        handleSubmit,
        initialValues,
        values = {},
        ...rest
      }) => {
        const activeDependencies = getRolesDependencies(values.roles, knownRoles)
        const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles, replicaset);
        const rolesColumns = (knownRoles && knownRoles.length > 6) ? 3 : 2;

        return (
          <form onSubmit={handleSubmit}>
            <SelectedReplicaset className={styles.splash} replicaset={replicaset} />
            <div className={styles.wrap}>
              <FormSpy
                subscription={{ values: true }}
                onChange={({ values }) => {
                  if (!values) return;
                  const vshardStorageRoleChecked = values.roles.some(role => storageRolesNames.includes(role));

                  if (!vshardStorageRoleChecked && typeof values.weight === 'string') {
                    form.change('weight', initialValues && initialValues.weight);
                  }

                  if (vshard_groups && vshard_groups.length === 1) {
                    if (vshardStorageRoleChecked && !values.vshard_group) {
                      form.change('vshard_group', vshard_groups[0].name);
                    }

                    if (
                      !vshardStorageRoleChecked
                      && !(initialValues && initialValues.vshard_group)
                      && values.vshard_group
                    ) {
                      form.change('vshard_group', null);
                    }
                  }
                }}
              />
              <Field name='alias'>
                {({ input: { name, value, onChange }, meta: { error } }) => (
                  <LabeledInput
                    className={styles.field}
                    label='Replica set name'
                    name={name}
                    onChange={onChange}
                    value={value}
                    error={error}
                    message={error}
                    largeMargins
                    autoFocus
                  />
                )}
              </Field>
              <Field name='roles'>
                {({ input: { name: fieldName, value, onChange } }) => (
                  <FormField
                    className={styles.wideField}
                    columns={rolesColumns}
                    label='Roles'
                    subTitle={(
                      <Button
                        intent='plain'
                        onClick={() => {
                          form.change(
                            fieldName,
                            !knownRoles || (value.length === knownRoles.length)
                              ? []
                              : knownRoles.map(({ name }) => name)
                          );
                        }}
                        size='xs'
                        text={value.length === (knownRoles && knownRoles.length) ? 'Deselect all' : 'Select all'}
                      />
                    )}
                    verticalSort
                    largeMargins
                  >
                    {knownRoles && knownRoles.reduceRight(
                      (acc, { name, dependencies }) => {
                        acc.push(
                          <Checkbox
                            onChange={() => {
                              const activeRoles = value.includes(name)
                                ? value.filter(x => x !== name)
                                : value.concat([name])

                              const prevDependencies = getRolesDependencies(value, knownRoles);
                              const rolesWithoutDependencies = activeRoles.filter(
                                role => !prevDependencies.includes(role)
                              );
                              const newDependencies = getRolesDependencies(rolesWithoutDependencies, knownRoles);

                              form.change(
                                fieldName,
                                uniq([...newDependencies, ...rolesWithoutDependencies])
                              )
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
                      },
                      []
                    )}
                  </FormField>
                )}
              </Field>
              <Field name='weight'>
                {({ input: { name, value, onChange }, meta: { error } }) => (
                  <LabeledInput
                    className={styles.field}
                    label='Replica set weight'
                    inputClassName={styles.weightInput}
                    name={name}
                    error={error}
                    value={value}
                    onChange={onChange}
                    disabled={!values.roles.some(role => storageRolesNames.includes(role))}
                    placeholder='Auto'
                    message={errors.weight}
                    largeMargins
                  />
                )}
              </Field>
              <Field name='vshard_group'>
                {({ input: { name: fieldName, value, onChange } }) => (
                  <FormField
                    className={styles.field}
                    label='Vshard group'
                    info={vshardTooltipInfo}
                    largeMargins
                  >
                    {vshard_groups && vshard_groups.map(({ name }) => (
                      <RadioButton
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
              <Field name='all_rw'>
                {({ input: { name: fieldName, value, onChange } }) => (
                  <FormField
                    className={styles.field}
                    label='All writable'
                    info={allRwTooltipInfo}
                    largeMargins
                  >
                    <Checkbox
                      onChange={onChange}
                      name={fieldName}
                      checked={value}
                    >
                      Make all instances writeable
                    </Checkbox>
                  </FormField>
                )}
              </Field>
              <Field name='master'>
                {({ input: { name, value, onChange }, meta: { error } }) => (
                  <LabeledInput
                    className={cx('ser', styles.wideField)}
                    itemClassName={styles.radioWrap}
                    label='Failover priority'
                    inputComponent={ServerSortableList}
                    value={value}
                    key={'uuid'}
                    onChange={v => form.change(name, v)}
                    replicaset={replicaset}
                    serverMap={compose(
                      map(([val]) => val),
                      groupBy(prop('uuid'))
                    )(replicaset.servers || [])}
                    selfURI={selfURI}
                    largeMargins
                  />
                )}
              </Field>
            </div>
            <PopupFooter
              controls={([
                <Button type='button' onClick={onCancel} size='l'>Cancel</Button>,
                <Button
                  className='meta-test__EditReplicasetSaveBtn'
                  intent='primary'
                  type='submit'
                  disabled={!!Object.keys(errors).length}
                  size='l'
                >
                  Save
                </Button>
              ])}
            />
          </form>
        )
      }}
    </Form>
  );
}

export default EditReplicasetForm;
