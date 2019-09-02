// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { Formik } from 'formik';
import * as R from 'ramda';
import SelectedReplicaset from 'src/components/SelectedReplicaset';
import Text from 'src/components/Text';
import InputText from 'src/components/InputText';
import LabeledInput from 'src/components/LabeledInput';
import Checkbox from 'src/components/Checkbox';
import RadioButton from 'src/components/RadioButton';
import Scrollbar from 'src/components/Scrollbar';
import Button from 'src/components/Button';
import PopupBody from 'src/components/PopupBody';
import PopupFooter from 'src/components/PopupFooter';
import FormField from 'src/components/FormField';
import type {
  Role,
  Replicaset,
  VshardGroup,
  EditReplicasetMutationVariables
} from 'src/generated/graphql-typing';
import {
  getDependenciesString,
  getRolesDependencies,
  isVShardGroupInputDisabled,
  validateForm
} from 'src/misc/replicasetFormFunctions';
import { VSHARD_STORAGE_ROLE_NAME } from 'src/constants';
import { ServerSortableList } from './ServerSortableList';

const styles = {
  popupBody: css`
    min-height: 100px;
    height: 80vh;
    max-height: 480px;
  `,
  form: css`
    /* margin-left: -16px;
    margin-right: -16px; */
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
  wideField: css`
    flex-basis: 100%;
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

type EditReplicasetFormProps = {
  knownRoles?: Role[],
  loading?: boolean,
  onCancel: () => void,
  onSubmit: (d: EditReplicasetMutationVariables) => void,
  replicaset?: Replicaset,
  vshard_groups?: VshardGroup[]
};

const EditReplicasetForm = ({
  knownRoles,
  loading,
  onCancel,
  onSubmit,
  vshard_groups,
  replicaset
}:
EditReplicasetFormProps) => {
  if (!replicaset) {
    return 'Replicaset not found';
  }

  return (
    <Formik
      initialValues={{
        alias: replicaset.alias,
        roles: replicaset.roles || [],
        vshard_group: replicaset.vshard_group,
        master: replicaset.servers.map(({ uuid }) => uuid),
        weight: replicaset.weight
      }}
      validate={validateForm}
      onSubmit={(values, { setSubmitting }) => {
        onSubmit({
          ...values,
          alias: values.alias || null,
          uuid: replicaset.uuid,
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
        const VShardGroupInputDisabled = isVShardGroupInputDisabled(values.roles, replicaset);
        const rolesColumns = (knownRoles && knownRoles.length > 6) ? 3 : 2;

        return (
          <form className={styles.form} onSubmit={handleSubmit}>
            <PopupBody className={styles.popupBody}>
              <Scrollbar>
                <div className={styles.wrap}>
                  <SelectedReplicaset className={styles.splash} replicaset={replicaset} />
                  <LabeledInput className={styles.wideField} label='Enter name of replica set'>
                    <InputText
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
                    {knownRoles && knownRoles.map(({ name, dependencies }) => {
                      return (
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
                      )
                    })}
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
                    <InputText
                      className={styles.weightInput}
                      name='weight'
                      error={errors.weight}
                      value={values.weight}
                      onChange={handleChange}
                      disabled={!vshardStorageRoleChecked}
                    />
                    <Text variant='p' className={styles.errorMessage}>{errors.weight}</Text>
                  </LabeledInput>
                  <LabeledInput
                    className={cx('ser', styles.wideField)}
                    itemClassName={styles.radioWrap}
                    label='Include servers'
                  >
                    <ServerSortableList
                      value={values.master}
                      key={'uuid'}
                      onChange={v => setFieldValue('master', v)}
                      serverMap={R.compose(R.map(([val]) => val), R.groupBy(R.prop('uuid')))(replicaset.servers || [])}
                    />
                  </LabeledInput>
                </div>
              </Scrollbar>
            </PopupBody>
            <PopupFooter
              controls={([
                <Button type='button' onClick={onCancel}>Cancel</Button>,
                <Button
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
    </Formik>
  );
}

export default EditReplicasetForm;
