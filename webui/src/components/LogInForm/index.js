import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import { logIn } from 'src/store/actions/auth.actions';
import { Formik, Form } from 'formik'
import * as yup from 'yup'
import Modal from 'src/components/Modal';
import Button from 'src/components/Button';
import { BaseModal } from '../Modal';
import { FieldConstructor, FormContainer } from '../FieldGroup';
import InputText from '../InputText';
import Alert from '../Alert';
import Text from '../Text';
import { ModalInfoContainer } from '../styled'

const schema = yup.object().shape({
  username: yup.string().required(),
  password: yup.string().required()
})

const styles = {
  formWrap: css`
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    right: 0;
    z-index: 1;
    background: #f0f2f5;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    box-sizing: border-box;
    overflow: auto;
  `,
  form: css`
    width: 100%;
    max-width: 300px;
  `,
  submitBtn: css`
    width: 100%;
  `,
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
  `,
  splashContainer: css`
    display: flex;
    flex-direction: row;
  `,
  logoContainer: css`
    width: 68px;
    flex-grow: 0;
    flex-shrink: 0;
    background: #000;
    display: flex;
    flex-direction: column;
    justify-content: center;
    position: relative;
  `,
  logo: css`
    width: 210px;
    position: absolute;
    transform: translate3d(-50%, -50%, 0) rotate(-90deg);
    left: 50%;
    top: 50%;
  `,
  formContainer: css`
    flex-grow: 1;
    padding: 24px 32px;
  `
};


const formProps = [
  { label: 'Username', field: 'username' },
  { label: 'Password', field: 'password', type: 'password' }
]

class LogInForm extends React.Component {
  handleSubmit = async (values, actions) => {
    try {
      await this.props.logIn(values);
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
        validationSchema={schema}
        onSubmit={this.handleSubmit}
        initialValues={{
          username: '',
          password: ''
        }}
      >
        {({
          values,
          errors,
          touched,
          handleChange,
          handleBlur
        }) =>
          <Form>

            {formProps.map(({ label, field, type }) =>
              <FieldConstructor
                key={field}
                label={label}
                required={true}
                input={
                  <InputText
                    value={values[field]}
                    onBlur={handleBlur}
                    onChange={handleChange}
                    name={field}
                    type={type || 'text'}
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
              {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
              <Button intent="primary" type='submit'>Login</Button>
            </div>
          </Form>
        }
      </Formik>
    );
  }
}

const mapStateToProps = ({
  app: {
    appDataRequestStatus: {
      loaded
    },
    authParams: {
      implements_check_password
    }
  },
  auth: {
    authorizationEnabled,
    authorized,
    error,
  },
  ui: {
    fetchingAuth
  }
}) => ({
  authorizationRequired: implements_check_password && authorizationEnabled && !authorized,
  loaded,
  error,
  fetchingAuth
});

const ConnectedLogInForm = connect(mapStateToProps, { logIn })(LogInForm);

const SplashLogInForm = ({
  authorizationRequired,
  loaded,
  ...props
}) => {
  return loaded && authorizationRequired
    ? (
      <BaseModal bgColor={'#f0f2f5'}>
        <div className={styles.splashContainer}>
          <div className={styles.logoContainer}>
            <img src={window.tarantool_enterprise_core.logo} className={styles.logo} />
          </div>
          <div className={styles.formContainer}>
            <Text variant={'h1'}>Authorization</Text>
            <div className={css`margin: 16px 0 48px 0`}>
              <Text variant={'basic'} className={css`color: rgba(0, 0, 0, 0.65)`}>Please, input your credentials</Text>
            </div>
            <LogInForm {...props} />
          </div>
        </div>
      </BaseModal>
    )
    : null;
};

export const ModalLogInForm = ({ onCancel, visible, ...props }) => (
  <Modal
    title={'Authorization'}
    visible={visible}
    footer={null}
    onClose={onCancel}
    destroyOnClose={true}
  >
    <ModalInfoContainer>
      <ConnectedLogInForm {...props} onClose={onCancel}/>
    </ModalInfoContainer>
  </Modal>
)

export default connect(mapStateToProps, { logIn })(SplashLogInForm);
