import React from 'react';
import { connect } from 'react-redux';
import { Alert, Button, Input, Text } from '@tarantool.io/ui-kit';
import { css } from 'emotion';
import { addUser } from 'src/store/actions/users.actions';
import { Formik, Form } from 'formik';
import { FieldConstructor } from '../FieldGroup'
import * as Yup from 'yup';

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


const formProps = [
  'username',
  'password',
  'email',
  'fullname'
]

const requiredFields = [
  'username',
  'password'
]

class UserAddForm extends React.Component {
  submit = async (values, actions) => {
    const { addUser } = this.props;
    try {
      await addUser(values);

    } catch(e) {
      actions.setFieldError('common', e.message)
    } finally{
      actions.setSubmitting(false)
    }
  };

  render() {
    const {
      error,
      onClose
    } = this.props;


    return (
      <Formik
        initialValues={{
          username: '',
          fullname: '',
          email: '',
          password: ''
        }}
        validationSchema={schema}
        onSubmit={this.submit}
      >
        {({
          values,
          errors,
          handleChange,
          handleBlur,
          touched,
          handleSubmit,
          isSubmitting
        }) => (<Form>
          {formProps.map(field =>
            <FieldConstructor
              key={field}
              label={field}
              required={requiredFields.includes(field)}
              input={
                <Input
                  value={values[field]}
                  onBlur={handleBlur}
                  onChange={handleChange}
                  name={field}
                  type={field === 'password' ? 'password' : 'text'}
                  size='m'
                />
              }
              error={touched[field] && errors[field]}
            />
          )}
          {error || errors.common ? (
            <Alert type="error" className={styles.error}>
              <Text variant="basic">{error || errors.common}</Text>
            </Alert>
          ) : null}
          <div className={styles.actionButtons}>
            {onClose && (
              <Button onClick={onClose} className={styles.cancelButton} size='l'>Cancel</Button>
            )}
            <Button intent="primary" type='submit' size='l'>Add</Button>
          </div>
        </Form>
        )}
      </Formik>

    );
  }
}

const mapStateToProps = ({
  users: {
    mutationError: error
  },
  ui: {
    fetchingUserMutation: loading
  }
}) => ({
  error,
  loading
});

const connectedForm = connect(
  mapStateToProps,
  { addUser }
)(UserAddForm);

export default connectedForm;
