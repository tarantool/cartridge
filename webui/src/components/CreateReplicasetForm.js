// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { Formik } from 'formik';
import * as R from 'ramda';
import SelectedServersList from 'src/components/SelectedServersList';
import LabeledInput from 'src/components/LabeledInput';
import {
  Button,
  Checkbox,
  Input,
  PopupBody,
  PopupFooter,
  RadioButton,
  Text
} from '@tarantool.io/ui-kit';
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
  <Formik
    initialValues={{
      alias: '',
      roles: [],
      vshard_group: null,
      weight: null
    }}
    validate={validateForm}
    onSubmit={(values, { setSubmitting }) => {
      onSubmit({
        ...values,
        alias: values.alias || null,
        uri: (selectedServers && selectedServers[0].uri) || '',
        weight: parseInt(values.weight, 10)
      });
    }}
  >
    {({
      values,
      errors,
      touched,
      handleChange,
      handleBlur,
      handleSubmit,
      isSubmitting,
      setFieldValue
    }) => {
      const vshardStorageRoleChecked = values.roles.includes(VSHARD_STORAGE_ROLE_NAME);
      const activeDependencies = getRolesDependencies(values.roles, knownRoles)
      const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles);
      const rolesColumns = (knownRoles && knownRoles.length > 6) ? 3 : 2;

      return (
        <form className={styles.form} onSubmit={handleSubmit}>
          <PopupBody className={styles.popupBody} innerClassName={styles.wrap} scrollable>
            <SelectedServersList className={styles.splash} serverList={selectedServers} />
            <LabeledInput className={styles.wideField} label='Enter name of replica set'>
              <Input
                name='alias'
                className={cx(
                  styles.input,
                  styles.aliasInput
                )}
                onChange={handleChange}
                value={values.alias}
                error={errors.alias}
              />
              <Text variant='p' className={styles.errorMessage}>{errors.alias}</Text>
            </LabeledInput>
            <FormField className={styles.wideField} label='Roles' columns={rolesColumns} verticalSort>
              {knownRoles && knownRoles.reduceRight(
                (acc, { name, dependencies }) => {
                  acc.push(
                    <Checkbox
                      onChange={() => {
                        const activeRoles = values.roles.includes(name)
                          ? values.roles.filter(x => x !== name)
                          : values.roles.concat([name])

                        const prevDependencies = getRolesDependencies(values.roles, knownRoles);
                        const rolesWithoutDependencies = activeRoles.filter(
                          role => !prevDependencies.includes(role)
                        );
                        const newDependencies = getRolesDependencies(rolesWithoutDependencies, knownRoles);

                        setFieldValue(
                          'roles',
                          R.uniq([...newDependencies, ...rolesWithoutDependencies])
                        )
                      }}
                      name='roles'
                      value={name}
                      checked={values.roles.includes(name)}
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
            <FormField className={styles.vshardGroupField} label='Group' info={info}>
              {vshard_groups && vshard_groups.map(({ name }) => (
                <RadioButton
                  onChange={handleChange}
                  name='vshard_group'
                  value={name}
                  checked={name === values.vshard_group}
                  disabled={VShardGroupInputDisabled}
                >
                  {name}
                </RadioButton>
              ))}
            </FormField>
            <LabeledInput className={styles.weightField} label='Weight'>
              <Input
                className={styles.weightInput}
                name='weight'
                error={errors.weight}
                value={values.weight}
                onChange={handleChange}
                disabled={!vshardStorageRoleChecked}
              />
              <Text variant='p' className={styles.errorMessage}>{errors.weight}</Text>
            </LabeledInput>
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
  </Formik>
);

export default CreateReplicasetForm;
