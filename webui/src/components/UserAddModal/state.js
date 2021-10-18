// @flow
import { combine, createEffect, createEvent, createStore, forward, guard, sample } from 'effector';
import { pickAll } from 'ramda';
import * as Yup from 'yup';

import { createField } from 'src/misc/effectorForms';
import { addUserFx, hideModal, showUserAddModal } from 'src/store/effector/users';

// type InitFormProps = ?{ fullname?: string, email?: string };

type FormValuesType = ?{
  username: string | null,
  password: string | null,
  fullname: string | null,
  email: string | null,
};

export const createFormStore = () => {
  // store
  const emailField = createField('email', '');
  const fullnameField = createField('fullname', '');
  const usernameField = createField('username', '');
  const passwordField = createField('password', '');

  const $errors = createStore<Object | null>(null);
  const $isFormValid = $errors.map<boolean>((errors) => !errors);
  const $showAllErrors = createStore<boolean>(false);

  const resetForm = createEvent<mixed>('Reset form');
  const submitForm = createEvent<mixed>('Submit form');

  // init
  resetForm.watch(() => {
    emailField.reset();
    fullnameField.reset();
    passwordField.reset();
    usernameField.reset();
  });

  forward({ from: addUserFx.done, to: resetForm });
  forward({ from: hideModal, to: resetForm });

  guard({
    source: sample({
      source: combine({
        username: usernameField.$value,
        fullname: fullnameField.$value,
        password: passwordField.$value,
        email: emailField.$value,
        errors: $errors,
      }),
      clock: submitForm,
      fn: (values) => {
        const obj = pickAll(['email', 'fullname', 'username'], values);
        if (values.password) {
          obj.password = values.password;
        }
        return obj;
      },
    }),
    filter: $isFormValid,
    target: addUserFx,
  });

  // helpers
  const handleSubmit = (e: Event) => {
    e.preventDefault();
    submitForm();
  };

  const schema = Yup.object().shape({
    username: Yup.string().required(),
    fullname: Yup.string(),
    email: Yup.string().email(),
    password: Yup.string().required(),
  });

  const validateFx = createEffect<FormValuesType, void, { [string]: string }>({
    handler: (values) =>
      new Promise((resolve, reject) => {
        schema.validate(values, { abortEarly: false }).then(resolve, ({ inner }) => {
          const result = {};
          inner.forEach(({ message, path }) => (result[path] = message));
          reject(result);
        });
      }),
  });

  // $FlowFixMe
  sample({
    source: combine({
      username: usernameField.$value,
      fullname: fullnameField.$value,
      password: passwordField.$value,
      email: emailField.$value,
    }),
    clock: [usernameField.$value, fullnameField.$value, passwordField.$value, emailField.$value, showUserAddModal],
    target: validateFx,
  });

  $errors
    .on(validateFx.failData, (_, r) => r)
    .reset(validateFx.done)
    .reset(resetForm);

  $showAllErrors.on(submitForm, () => true).reset(resetForm);

  return {
    emailField,
    fullnameField,
    passwordField,
    usernameField,
    resetForm,
    $errors,
    $isFormValid,
    $showAllErrors,
    handleSubmit,
  };
};

export default createFormStore();
