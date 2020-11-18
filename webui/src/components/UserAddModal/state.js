// @flo - temporarely disable flow because of effector's sample typing problems
import {
  combine,
  createEffect,
  createEvent,
  createStore,
  guard,
  sample,
  forward
} from 'effector';
import * as Yup from 'yup';
import { pickAll } from 'ramda';
import { createField } from 'src/misc/effectorForms';
import {
  showUserAddModal,
  hideModal,
  addUserFx
} from 'src/store/effector/users';

type initFormProps = ?{ fullname?: string, email?: string };

type formValuesType = ?{
  username: string | null,
  password: string | null,
  fullname: string | null,
  email: string | null
};

export const createFormStore = (values: initFormProps) => {
  // store
  const emailField = createField('email', '');
  const fullnameField = createField('fullname', '');
  const usernameField = createField('username', '');
  const passwordField = createField('password', '');

  const $errors = createStore<Object | null>(null);
  const $isFormValid = $errors.map<bool>(errors => !errors);
  const $showAllErrors = createStore<bool>(false);

  const resetForm = createEvent<void>('Reset form');
  const submitForm = createEvent<void>('Submit form')

  // init
  resetForm.watch(() => {
    emailField.reset();
    fullnameField.reset();
    passwordField.reset();
    usernameField.reset();
  })

  forward({ from: hideModal, to: resetForm });

  guard({
    source: sample({
      source: combine(
        usernameField.$value,
        fullnameField.$value,
        passwordField.$value,
        emailField.$value,
        $errors,
        (
          username,
          fullname,
          password,
          email,
          errors
        ) => ({
          username,
          fullname,
          password,
          email,
          errors
        })
      ),
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
    target: addUserFx
  });

  // helpers
  const handleSubmit = (e: Event) => {
    e.preventDefault();
    submitForm();
  }

  const schema = Yup.object().shape({
    username: Yup.string().required(),
    fullname: Yup.string(),
    email: Yup.string().email(),
    password: Yup.string().required()
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
      usernameField.$value,
      fullnameField.$value,
      passwordField.$value,
      emailField.$value,
      (
        username,
        fullname,
        password,
        email
      ) => ({
        username,
        fullname,
        password,
        email
      })
    ),
    clock: [
      usernameField.$value,
      fullnameField.$value,
      passwordField.$value,
      emailField.$value,
      showUserAddModal
    ],
    target: validateFx
  });

  $errors
    .on(validateFx.failData, (_, r) => r)
    .reset(validateFx.done)
    .reset(resetForm);

  $showAllErrors
    .on(submitForm, () => true)
    .reset(resetForm);

  return {
    emailField,
    fullnameField,
    passwordField,
    usernameField,
    resetForm,
    $errors,
    $isFormValid,
    $showAllErrors,
    handleSubmit
  };
}

export default createFormStore();
