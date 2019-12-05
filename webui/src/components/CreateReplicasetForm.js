// @flow
import React from 'react';
import { css } from 'react-emotion';
import * as R from 'ramda';
import { Form, Field, FormSpy } from 'react-final-form';
import {
  Button,
  Checkbox,
  Input,
  PopupBody,
  PopupFooter,
  RadioButton,
  Text
} from '@tarantool.io/ui-kit';
import SelectedServersList from 'src/components/SelectedServersList';
import LabeledInput from 'src/components/LabeledInput';
import FormField from 'src/components/FormField';
import type {
  Server,
  Role,
  Replicaset,
  VshardGroup
} from 'src/generated/graphql-typing';
import type { CreateReplicasetArgs } from 'src/store/request/clusterPage.requests';
import {
  getDependenciesString,
  getRolesDependencies,
  isVShardGroupInputDisabled,
  validateForm
} from 'src/misc/replicasetFormFunctions';
import { VSHARD_STORAGE_ROLE_NAME } from 'src/constants';

const styles = {
  form: css`
  `,
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
  errorMessage: css`
    display: block;
    height: 20px;
    color: #F5222D;
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
  `
}

const vshardTooltipInfo = <span>Group disabled not yet included the role of "<b>vshard-storage</b>"</span>;
const allRwTooltipInfo = 'Otherwise only leader in the replicaset is writeable';

const initialValues = {
  alias: '',
  all_rw: false,
  roles: [],
  vshard_group: null,
  weight: null
};

type CreateReplicasetFormProps = {
  knownRoles?: Role[],
  onCancel: () => void,
  onSubmit: (d: CreateReplicasetArgs) => void,
  replicasetList?: Replicaset[],
  selectedServers?: Server[],
  vshard_groups?: VshardGroup[]
};

const CreateReplicasetForm = ({
  knownRoles,
  onCancel,
  onSubmit,
  vshard_groups,
  replicasetList,
  selectedServers
}:
CreateReplicasetFormProps) => (
  <Form
    initialValues={initialValues}
    keepDirtyOnReinitialize
    validate={validateForm}
    onSubmit={values => {
      onSubmit({
        ...values,
        alias: values.alias || null,
        uri: (selectedServers && selectedServers[0].uri) || '',
        weight: parseInt(values.weight, 10)
      });
    }}
  >
    {({
      errors = {},
      form,
      handleSubmit,
      initialValues,
      values = {}
    }) => {
      const vshardStorageRoleChecked = values.roles.includes(VSHARD_STORAGE_ROLE_NAME);
      const activeDependencies = getRolesDependencies(values.roles, knownRoles)
      const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles);
      const rolesColumns = (knownRoles && knownRoles.length > 6) ? 3 : 2;

      return (
        <form className={styles.form} onSubmit={handleSubmit}>
          <PopupBody className={styles.wrap}>
            <SelectedServersList className={styles.splash} serverList={selectedServers} />
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

                  if (!values.roles.includes(VSHARD_STORAGE_ROLE_NAME) && values.vshard_group) {
                    form.change('vshard_group', null);
                  }
                }
              }}
            />
            <Field name='alias'>
              {({ input: { name, value, onChange }, meta: { error } }) => (
                <LabeledInput className={styles.field} label='Replica Set name'>
                  <Input
                    name={name}
                    className={styles.input}
                    onChange={onChange}
                    value={value}
                    error={error}
                  />
                  <Text variant='p' className={styles.errorMessage}>{error}</Text>
                </LabeledInput>
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
                <LabeledInput className={styles.field} label='Replica Set weight'>
                  <Input
                    className={styles.weightInput}
                    name={name}
                    error={error}
                    value={value}
                    onChange={onChange}
                    disabled={!vshardStorageRoleChecked}
                    placeholder='Auto'
                  />
                  <Text variant='p' className={styles.errorMessage}>{error}</Text>
                </LabeledInput>
              )}
            </Field>
            <Field name='vshard_group'>
              {({ input: { name: fieldName, value, onChange } }) => (
                <FormField className={styles.field} label='Vshard Group' info={vshardTooltipInfo}>
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
          </PopupBody>
          <PopupFooter
            controls={([
              <Button type='button' onClick={onCancel}>Cancel</Button>,
              <Button
                className='meta-test__CreateReplicaSetBtn'
                intent='primary'
                type='submit'
                disabled={Object.keys(errors).length > 0}
              >
                Create replica set
              </Button>
            ])}
          />
        </form>
      )
    }}
  </Form>
);

export default CreateReplicasetForm;
