// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { Formik } from 'formik';

import SelectedReplicaset from 'src/components/SelectedReplicaset';
import Text from 'src/components/Text';
import InputText from 'src/components/InputText';
import LabeledInput from 'src/components/LabeledInput';
import { CheckboxField } from 'src/components/Checkbox';
import RadioButton from 'src/components/RadioButton';
import Button from 'src/components/Button';
import PopupFooter from 'src/components/PopupFooter';
import FormField from 'src/components/FormField';
import type {
  Role,
  Replicaset,
  VshardGroup
} from 'src/generated/graphql-typing';
import { VSHARD_STORAGE_ROLE_NAME } from 'src/constants';

const styles = {
  form: css`
    display: flex;
    flex-wrap: wrap;
    margin-left: -16px;
    margin-right: -16px;
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
  wideField: css`
    flex-basis: calc(100% - 32px);
    max-width: calc(100% - 32px);
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

const validateForm = ({
  alias,
  roles,
  vshard_group,
  weight
}) => {
  const errors = {};
  const numericWeight = Number(weight);

  if (isNaN(numericWeight) || numericWeight < 0 || numericWeight % 1) {
    errors.weight = 'Field accepts number, ex: 0, 1, 2...'
  }

  if (alias.length > 63) {
    errors.alias = 'Alias must not exceed 63 character';
  } else if (alias.length && !(/^[a-zA-Z0-9-_\.]+$/).test(alias)) {
    errors.alias = 'Alias must contain only alphanumerics [a-zA-Z], dots (.), underscores (_) or dashes (-)';
  }

  return errors;
};

type EditReplicasetFormData = {
  alias: string,
  roles?: string[],
  vshard_group?: string,
  weight?: string
};

type EditReplicasetFormProps = {
  knownRoles?: Role[],
  loading?: boolean,
  onCancel: () => void,
  onSubmit: (d: EditReplicasetFormData) => void,
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
        roles: replicaset.roles,
        vshard_group: replicaset.vshard_group,
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
        isSubmitting
      }) => {
        const vshardStorageRoleChecked = values.roles.includes(VSHARD_STORAGE_ROLE_NAME);

        return (
          <form className={styles.form} onSubmit={handleSubmit}>
            <SelectedReplicaset className={styles.wideField} replicaset={replicaset} />
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
            <FormField className={styles.wideField} label='Roles' columns={3}>
              {knownRoles && knownRoles.map(({ name }) => (
                <CheckboxField
                  onChange={handleChange}
                  name='roles'
                  value={name}
                >
                  {name}
                </CheckboxField>
              ))}
            </FormField>
            <FormField className={styles.vshardGroupField} label='Group' info={info}>
              {vshard_groups && vshard_groups.map(({ name }) => (
                <RadioButton
                  onChange={handleChange}
                  name='vshard_group'
                  value={name}
                  checked={name === values.vshard_group}
                  disabled={!vshardStorageRoleChecked}
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
            <PopupFooter
              className={styles.wideField}
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
