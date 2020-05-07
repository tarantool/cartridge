import React from 'react';
import { useStore } from 'effector-react';
import {
  Alert,
  Button,
  InputPassword,
  LabeledInput,
  Text
} from '@tarantool.io/ui-kit';
import { css } from 'emotion';
import { Formik, Form } from 'formik';
import * as Yup from 'yup';
import usersStore from 'src/store/effector/users';

const { addUserFx } = usersStore;

const schema = Yup.object().shape({
  username: Yup.string().required(),
  fullname: Yup.string(),
  email: Yup.string().email(),
  password: Yup.string().required()
})

const styles = {
  error: css`
    margin-bottom: 30px;
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
  try {
    await addUserFx(values);
  } catch(e) {
    return;
  }
};

export const UserAddForm = ({
  error,
  onClose
}) => {
  const pending = useStore(addUserFx.pending);

  return (
    <Formik
      initialValues={{
        username: '',
        fullname: '',
        email: '',
        password: ''
      }}
      validationSchema={schema}
      onSubmit={submit}
    >
      {({
        values,
        errors,
        handleChange,
        handleBlur,
        touched,
        handleSubmit
      }) => (
        <Form>
          <LabeledInput
            label='Username'
            name='username'
            value={values['username']}
            error={touched['username'] && errors['username']}
            message={errors['username']}
            onBlur={handleBlur}
            onChange={handleChange}
          />
          <LabeledInput
            label='Password'
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
            <Button intent="primary" type='submit' loading={pending}>Add</Button>
          </div>
        </Form>
      )}
    </Formik>
  );
};
