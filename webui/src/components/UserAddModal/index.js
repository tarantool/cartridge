import React from 'react';
import { useStore, createComponent } from 'effector-react';
import {
  Alert,
  Button,
  InputPassword,
  LabeledInput,
  Modal,
  Text
} from '@tarantool.io/ui-kit';
import { $userAddModal, addUserFx, hideModal } from 'src/store/effector/users';
import formStore from './state';

const {
  $errors,
  $showAllErrors,
  emailField,
  fullnameField,
  passwordField,
  usernameField,
  handleSubmit
} = formStore;

const EmailInput = createComponent(
  emailField,
  (
    { error, untouchedErrors },
    { blur, change, $field: { value, visited }, ...state }
  ) => (
    <LabeledInput
      label='Email'
      type='text'
      value={value}
      onChange={change}
      onBlur={blur}
      error={(visited || untouchedErrors) && error}
      message={(visited || untouchedErrors) && error}
    />
  )
);

const FullnameInput = createComponent(
  fullnameField,
  ({ error }, { change, $field: { value, visited }, ...state }) => (
    <LabeledInput
      label='Full name'
      type='text'
      value={value}
      onChange={change}
      error={visited && error}
      message={visited && error}
    />
  )
);

const UsernameInput = createComponent(
  usernameField,
  (
    { error, untouchedErrors },
    { blur, change, $field: { value, visited }, ...state }
  ) => (
    <LabeledInput
      label='Username'
      type='text'
      value={value}
      onChange={change}
      onBlur={blur}
      error={(visited || untouchedErrors) && error}
      message={(visited || untouchedErrors) && error}
    />
  )
);

const PasswordInput = createComponent(
  passwordField,
  (
    { error, untouchedErrors },
    { blur, change, $field: { value, visited }, $disabled: disabled }
  ) => (
    <LabeledInput
      label='Password'
      type='password'
      value={value}
      onChange={change}
      onBlur={blur}
      disabled={disabled}
      inputComponent={InputPassword}
      error={(visited || untouchedErrors) && error}
      message={(visited || untouchedErrors) && error}
    />
  )
);

export const UserAddModal = () => {
  const pending = useStore(addUserFx.pending);
  const { visible, error } = useStore($userAddModal);
  const showAllErrors = useStore($showAllErrors);
  const errors = useStore($errors);

  return (
    <Modal
      className='meta-test__UserAddForm'
      title="Add a new user"
      visible={visible}
      onClose={hideModal}
      onSubmit={handleSubmit}
      footerControls={[
        hideModal && <Button intent="base" onClick={hideModal}>Cancel</Button>,
        <Button intent="primary" type='submit' loading={pending}>Add</Button>
      ]}
    >
      <UsernameInput
        error={errors && errors.username}
        untouchedErrors={showAllErrors}
      />
      <PasswordInput
        error={errors && errors.password}
        untouchedErrors={showAllErrors}
      />
      <EmailInput
        error={errors && errors.email}
        untouchedErrors={showAllErrors}
      />
      <FullnameInput />
      {error || (errors && errors.common)
        ? (
          <Alert type='error'>
            <Text variant='basic'>{error || (errors && errors.common)}</Text>
          </Alert>
        )
        : null}
    </Modal>
  );
};
