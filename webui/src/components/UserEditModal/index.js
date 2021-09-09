import React from 'react';
import { createComponent, useStore } from 'effector-react';
import { Alert, Button, InputPassword, LabeledInput, Modal, Text } from '@tarantool.io/ui-kit';

import { $userEditModal, editUserFx, hideModal } from 'src/store/effector/users';

import formStore from './state';

const { $errors, emailField, fullnameField, passwordField, handleSubmit } = formStore;

const EmailInput = createComponent(emailField, ({ error }, { blur, change, $field: { value, visited } }) => (
  <LabeledInput
    label="Email"
    type="text"
    value={value}
    onChange={change}
    onBlur={blur}
    error={visited && error}
    message={visited && error}
  />
));

const FullnameInput = createComponent(fullnameField, ({ error }, { change, $field: { value } }) => (
  <LabeledInput label="Full name" type="text" value={value} onChange={change} error={error} message={error} />
));

const PasswordInput = createComponent(
  passwordField,
  ({ error }, { change, $field: { value }, $disabled: disabled }) => (
    <LabeledInput
      autoFocus
      label="New password"
      type="password"
      value={value}
      onChange={change}
      disabled={disabled}
      inputComponent={InputPassword}
      error={error}
      message={error}
    />
  )
);

export const UserEditModal = () => {
  const pending = useStore(editUserFx.pending);
  const { visible, username, error } = useStore($userEditModal);
  const errors = useStore($errors);

  return (
    <Modal
      className="meta-test__UserEditModal"
      title={`Edit ${username}`}
      visible={visible}
      onClose={hideModal}
      onSubmit={handleSubmit}
      footerControls={[
        hideModal && (
          <Button key="Cancel" intent="base" onClick={hideModal} size="l">
            Cancel
          </Button>
        ),
        <Button key="Save" intent="primary" type="submit" loading={pending} size="l">
          Save
        </Button>,
      ].filter(Boolean)}
    >
      <PasswordInput />
      <EmailInput error={errors && errors.email} />
      <FullnameInput />
      {error || (errors && errors.common) ? (
        <Alert type="error">
          <Text variant="basic">{error || (errors && errors.common)}</Text>
        </Alert>
      ) : null}
    </Modal>
  );
};
