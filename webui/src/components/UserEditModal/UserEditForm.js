import React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import { css } from 'emotion';
import { editUser } from 'src/store/actions/users.actions';
import { FieldConstructor, FormContainer } from '../FieldGroup';
import InputText from '../InputText';
import { Formik, Form } from 'formik';
import * as Yup from 'yup';
import * as R from 'ramda';


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


const formProps = [
  { label: 'New password', field: 'password' },
  { label: 'email', field: 'email' },
  { label: 'fullname', field: 'fullname' }
]


class UserEditForm extends React.Component {
  submit = async (values, actions) => {
    const { editUser, username } = this.props;
    try {
      await editUser({ ...R.filter(R.identity, values), username });
    } catch(e) {
      actions.setFieldError('common', e.message)
    } finally{
      actions.setSubmitting(false)
    }
  };

  render() {
    const {
      error,
      username,
      fullname,
      email,
      onClose
    } = this.props;

    return (
      <Formik
        initialValues={{
          fullname,
          email,
          password: ''
        }}
        validationSchema={schema}
        onSubmit={this.submit}
      >
        {({
          values,
          errors,
          touched,
          handleChange,
          handleBlur,
          handleSubmit,
          isSubmitting
        }) => (<Form>
          <FormContainer>

            {formProps.map(({ label, field }) =>
              <FieldConstructor
                key={field}
                label={label}
                input={<InputText value={values[field]} onBlur={handleBlur} onChange={handleChange} name={field}/>}
                error={touched[field] && errors[field]}
              />
            )}
            <p className={styles.error}>{error || errors.common}</p>
            <div className={styles.actionButtons}>
              {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
              <Button intent="primary" type='submit'>Save</Button>
            </div>
          </FormContainer>
        </Form>
        )}
      </Formik>
    );
  }
}

const selectUser = (state, username) => {
  let user = null;
  state.users.items.some(item => {
    if (item.username === username) {
      user = item;
      return true;
    }
    return false;
  });
  return user;
};

const mapStateToProps = state => {
  const {
    users: {
      mutationError: error
    },
    ui: {
      fetchingUserMutation: loading,
      editUserId: username
    }
  } = state;

  return {
    error,
    loading,
    username,
    ...(username && selectUser(state, username))
  };
};

const connectedForm = connect(
  mapStateToProps,
  { editUser }
)(UserEditForm);

export default connectedForm;
