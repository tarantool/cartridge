// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { Formik } from 'formik';

import Scrollbar from 'src/components/Scrollbar';
import SelectedServersList from 'src/components/SelectedServersList';
import Text from 'src/components/Text';
import InputText from 'src/components/InputText';
import LabeledInput from 'src/components/LabeledInput';
import { CheckboxField } from 'src/components/Checkbox';
import RadioButton from 'src/components/RadioButton';
import Button from 'src/components/Button';
import PopupBody from 'src/components/PopupBody';
import PopupFooter from 'src/components/PopupFooter';
import FormField from 'src/components/FormField';
import type {
  Server,
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
  popupBody: css`
    min-height: 100px;
    height: 80vh;
    max-height: 480px;
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

type CreateReplicasetFormData = {
  alias: string,
  roles?: string[],
  vshard_group?: string,
  weight?: string
};

type CreateReplicasetFormProps = {
  knownRoles?: Role[],
  onCancel: () => void,
  onSubmit: (d: CreateReplicasetFormData) => void,
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
        uri: selectedServers[0].uri,
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
          <PopupBody className={styles.popupBody}>
            <Scrollbar>
              <SelectedServersList className={styles.wideField} serverList={selectedServers} />
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
            </Scrollbar>
          </PopupBody>
          <PopupFooter
            className={styles.wideField}
            controls={([
              <Button type='button' onClick={onCancel}>Cancel</Button>,
              <Button intent='primary' type='submit' disabled={Object.keys(errors).length}>
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
