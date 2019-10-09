// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
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
  VshardGroup,
  CreateReplicasetMutationVariables
} from 'src/generated/graphql-typing';
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
  aliasInput: css`
    width: 50%;
  `,
  weightInput: css`
    width: 97px;
  `,
  errorMessage: css`
    display: block;
    height: 20px;
    color: #F5222D;
  `,
  popupBody: css`
    min-height: 100px;
    height: 80vh;
    max-height: 480px;
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
  vshardGroupField: css`
    flex-basis: calc(33% - 32px);
    flex-grow: 1;
    margin-left: 16px;
    margin-right: 16px;
  `,
  weightField: css`
    flex-basis: calc(66% - 32px);
    flex-grow: 1;
    margin-left: 16px;
    margin-right: 16px;
  `
}

const info = <span>Group disabled not yet included the role of "<b>vshard-storage</b>"</span>

const initialValues = {
  alias: '',
  roles: [],
  vshard_group: null,
  weight: null
};

type CreateReplicasetFormProps = {
  knownRoles?: Role[],
  onCancel: () => void,
  onSubmit: (d: CreateReplicasetMutationVariables) => void,
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
      values = {}
    }) => {
      const vshardStorageRoleChecked = values.roles.includes(VSHARD_STORAGE_ROLE_NAME);
      const activeDependencies = getRolesDependencies(values.roles, knownRoles)
      const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles);
      const rolesColumns = (knownRoles && knownRoles.length > 6) ? 3 : 2;

      return (
        <form className={styles.form} onSubmit={handleSubmit}>
          <PopupBody className={styles.popupBody} innerClassName={styles.wrap} scrollable>
            <SelectedServersList className={styles.splash} serverList={selectedServers} />
            {vshard_groups && vshard_groups.length === 1 && (
              <FormSpy
                subscription={{ values: true }}
                onChange={({ values }) => {
                  if (!values) return;

                  if (values.roles.includes(VSHARD_STORAGE_ROLE_NAME) && !values.vshard_group) {
                    form.change('vshard_group', vshard_groups[0].name);
                  }

                  if (!values.roles.includes(VSHARD_STORAGE_ROLE_NAME) && values.vshard_group) {
                    form.change('vshard_group', null);
                  }
                }}
              />
            )}
            <Field name='alias'>
              {({ input: { name, value, onChange }, meta: { error } }) => (
                <LabeledInput className={styles.wideField} label='Enter name of replica set'>
                  <Input
                    name={name}
                    className={cx(
                      styles.input,
                      styles.aliasInput
                    )}
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
            <Field name='vshard_group'>
              {({ input: { name: fieldName, value, onChange } }) => (
                <FormField className={styles.vshardGroupField} label='Group' info={info}>
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
            <Field name='weight'>
              {({ input: { name, value, onChange }, meta: { error } }) => (
                <LabeledInput className={styles.weightField} label='Weight'>
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
          </PopupBody>
          <PopupFooter
            controls={([
              <Button type='button' onClick={onCancel}>Cancel</Button>,
              <Button intent='primary' type='submit' disabled={Object.keys(errors).length > 0}>
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
