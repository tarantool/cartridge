import React from 'react';
import { useStore } from 'effector-react';
import { css } from 'emotion';
import {
  Alert,
  Button,
  Text,
  LabeledInput,
  InputPassword
} from '@tarantool.io/ui-kit';
import { Formik, Form } from 'formik';
import * as Yup from 'yup';
import { pickAll } from 'ramda';
import usersStore from 'src/store/effector/users';

const { $userToMutate, editUserFx } = usersStore;

const schema = Yup.object().shape({
  fullname: Yup.string(),
  email: Yup.string().email(),
  password: Yup.string()
})

const styles = {
  error: css`
    min-height: 24px;
    margin: 0 0 24px;
    color: #f5222d;
  `,
  actionButtons: css`
    display: flex;
    flex-direction: row;
    justify-content: flex-end;
  `,
  cancelButton: css`
    margin-right: 16px;
  `
};


const submit = async (values, actions) => {
  const obj = pickAll(['email', 'fullname', 'username'], values)
  if (values.password) {
    obj.password = values.password
  }
  try {
    await editUserFx(obj);
  } catch(e) {
    return;
  }
};


export const UserEditForm = ({
  error,
  onClose
}) => {
  const { username, fullname, email } = useStore($userToMutate);
  const pending = useStore(editUserFx.pending);

  return (
    <Formik
      initialValues={{
        fullname: fullname || '',
        email: email || '',
        password: ''
      }}
      validationSchema={schema}
      onSubmit={(values, actions) => submit({ ...values, username }, actions)}
    >
      {({
        values,
        errors,
        touched,
        handleChange,
        handleBlur,
        handleSubmit
      }) => (
        <Form>
          <LabeledInput
            label='New password'
            name='password'
            value={values['password']}
            error={touched['password'] && errors['password']}
            message={errors['password']}
            onBlur={handleBlur}
            onChange={handleChange}
            inputComponent={InputPassword}
          />
          <LabeledInput
            label='E-mail'
            name='email'
            value={values['email']}
            error={touched['email'] && errors['email']}
            message={errors['email']}
            onBlur={handleBlur}
            onChange={handleChange}
          />
          <LabeledInput
            label='Full name'
            name='fullname'
            value={values['fullname']}
            error={touched['fullname'] && errors['fullname']}
            message={errors['fullname']}
            onBlur={handleBlur}
            onChange={handleChange}
          />
          {error || errors.common ? (
            <Alert type="error" className={styles.error}>
              <Text variant="basic">{error || errors.common}</Text>
            </Alert>
          ) : null}
          <div className={styles.actionButtons}>
            {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
            <Button intent="primary" type='submit' loading={pending}>Save</Button>
          </div>
        </Form>
      )}
    </Formik>
  );
};
