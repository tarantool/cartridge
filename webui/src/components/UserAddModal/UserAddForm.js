import React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import Input from 'src/components/Input';
import { css } from 'emotion';
import { addUser } from 'src/store/actions/users.actions';
import { Formik, Form } from 'formik';
import { FormContainer, FieldConstructor } from '../FieldGroup'
import * as Yup from 'yup';
import InputText from '../InputText';

const schema = Yup.object().shape({
  username: Yup.string().required(),
  fullname: Yup.string(),
  email: Yup.string().email(),
  password: Yup.string().required()
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
      loading,
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
          <FormContainer>

            {formProps.map(field =>
              <FieldConstructor
                key={field}
                label={field}
                required={requiredFields.includes(field)}
                input={<InputText value={values[field]} onBlur={handleBlur} onChange={handleChange} name={field}/>}
                error={touched[field] && errors[field]}
              />
            )}
            <p className={styles.error}>{error || errors.common}</p>
            <div className={styles.actionButtons}>
              {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
              <Button intent="primary" type='submit'>Add</Button>
            </div>
          </FormContainer>
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
