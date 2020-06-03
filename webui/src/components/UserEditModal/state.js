// @flow
import {
  createEvent,
  sample,
  forward,
  createEffect,
  createStore,
  guard,
  combine
} from 'effector';
import * as Yup from 'yup';
import { pickAll } from 'ramda';
import { createField } from 'src/misc/effectorForms';
import {
  hideModal,
  $usersList,
  showUserEditModal,
  $usernameToMutate,
  editUserFx
} from 'src/store/effector/users';

type initFormProps = ?{ fullname?: string, email?: string };

type formValuesType = ?{
  password?: string,
  fullname?: string,
  email?: string
};

export const createFormStore = (values: initFormProps) => {
  // store
  const emailField = createField('email', (values && values.email) || '');
  const fullnameField = createField('fullname', (values && values.fullname) || '');
  const passwordField = createField('password', '');

  const $errors = createStore<Object | null>(null);
  const $isFormValid = $errors.map(errors => !errors);

  const resetForm = createEvent<initFormProps>('Reset form');
  const submitForm = createEvent<void>('Submit form');

  // init
  resetForm.watch((user: ?initFormProps) => {
    emailField.$value.defaultState = (user && user.email) || '';
    fullnameField.$value.defaultState = (user && user.fullname) || '';
    emailField.reset();
    fullnameField.reset();
    passwordField.reset();
  })

  forward({ from: hideModal, to: resetForm });

  sample({
    source: $usersList,
    clock: showUserEditModal,
    fn: (usersList, username) => usersList.find(user => user.username === username) || null,
    target: resetForm
  });

  guard({
    source: sample({
      source: {
        username: $usernameToMutate,
        fullname: fullnameField.$value,
        password: passwordField.$value,
        email: emailField.$value,
        errors: $errors
      },
      clock: submitForm,
      fn: values => {
        const obj = pickAll(['email', 'fullname', 'username'], values)
        if (values.password) {
          obj.password = values.password;
        }
        return obj;
      }
    }),
    filter: $isFormValid,
    target: editUserFx
  });

  // helpers
  const handleSubmit = (e: Event) => {
    e.preventDefault();
    submitForm();
  }

  const schema = Yup.object().shape({
    fullname: Yup.string(),
    email: Yup.string().email(),
    password: Yup.string()
  })

  const validateFx = createEffect<formValuesType, void, { [string]: string }>({
    handler: values => new Promise((resolve, reject) => {
      schema.validate(values, { abortEarly: false })
        .then(
          resolve,
          ({ inner }) => {
            const result = {};
            inner.forEach(({ message, path }) => result[path] = message);
            reject(result);
          }
        );
    })
  })

  sample({
    source: combine(
      fullnameField.$value,
      passwordField.$value,
      emailField.$value,
      (fullname, password, email) => ({ fullname, password, email })
    ),
    clock: [
      fullnameField.$value,
      passwordField.$value,
      emailField.$value,
      showUserEditModal
    ],
    target: validateFx
  });

  $errors
    .on(validateFx.failData, (_, r) => r)
    .reset(validateFx.done);

  return {
    emailField,
    fullnameField,
    passwordField,
    $errors,
    resetForm,
    handleSubmit
  };
}

export default createFormStore();
