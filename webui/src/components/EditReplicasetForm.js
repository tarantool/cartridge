// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import * as R from 'ramda';
import { Form, Field, FormSpy } from 'react-final-form';
import {
  Button,
  Checkbox,
  LabeledInput,
  PopupBody,
  PopupFooter,
  RadioButton
} from '@tarantool.io/ui-kit';
import SelectedReplicaset from 'src/components/SelectedReplicaset';
import FormField from 'src/components/FormField';
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
import { VSHARD_STORAGE_ROLE_NAME } from 'src/constants';
import ServerSortableList from './ServerSortableList';

const styles = {
  wrap: css`
    display: flex;
    flex-wrap: wrap;
  `,
  input: css`
    margin-bottom: 4px;
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
    margin-bottom: 24px;
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
  selfURI?: string
};

const EditReplicasetForm = ({
  knownRoles,
  loading,
  onCancel,
  onSubmit,
  vshard_groups,
  replicaset,
  selfURI
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
        const vshardStorageRoleChecked = values.roles.includes(VSHARD_STORAGE_ROLE_NAME);
        const activeDependencies = getRolesDependencies(values.roles, knownRoles)
        const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles, replicaset);
        const rolesColumns = (knownRoles && knownRoles.length > 6) ? 3 : 2;

        return (
          <form onSubmit={handleSubmit}>
            <PopupBody className={styles.wrap}>
              <SelectedReplicaset className={styles.splash} replicaset={replicaset} />
              <FormSpy
                subscription={{ values: true }}
                onChange={({ values }) => {
                  if (!values) return;

                  if (!values.roles.includes(VSHARD_STORAGE_ROLE_NAME) && typeof values.weight === 'string') {
                    form.change('weight', initialValues && initialValues.weight);
                  }

                  if (vshard_groups && vshard_groups.length === 1) {
                    if (values.roles.includes(VSHARD_STORAGE_ROLE_NAME) && !values.vshard_group) {
                      form.change('vshard_group', vshard_groups[0].name);
                    }

                    if (
                      !values.roles.includes(VSHARD_STORAGE_ROLE_NAME)
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
                    inputClassName={styles.input}
                    onChange={onChange}
                    value={value}
                    error={error}
                    message={error}
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
                                R.uniq([...newDependencies, ...rolesWithoutDependencies])
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
                    disabled={!vshardStorageRoleChecked}
                    placeholder='Auto'
                    message={errors.weight}
                  />
                )}
              </Field>
              <Field name='vshard_group'>
                {({ input: { name: fieldName, value, onChange } }) => (
                  <FormField className={styles.field} label='Vshard group' info={vshardTooltipInfo}>
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
                  <FormField className={styles.field} label='All writable' info={allRwTooltipInfo}>
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
                    serverMap={R.compose(
                      R.map(([val]) => val),
                      R.groupBy(R.prop('uuid'))
                    )(replicaset.servers || [])}
                    selfURI={selfURI}
                  />
                )}
              </Field>
            </PopupBody>
            <PopupFooter
              controls={([
                <Button type='button' onClick={onCancel}>Cancel</Button>,
                <Button
                  className='meta-test__EditReplicasetSaveBtn'
                  intent='primary'
                  type='submit'
                  disabled={!!Object.keys(errors).length}
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
