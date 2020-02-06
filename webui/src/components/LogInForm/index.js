import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import { logIn } from 'src/store/actions/auth.actions';
import { Formik, Form } from 'formik'
import * as yup from 'yup'
import { FieldConstructor } from '../FieldGroup';
import {
  Alert,
  Button,
  BaseModal,
  Input,
  Checkbox,
  InputGroup,
  Scrollbar,
  Modal,
  Text,
  Spin
} from '@tarantool.io/ui-kit';
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
  `,
  welcomeMessage: css`
    height: 150px;
    border: 1px solid #ddd;
    border-radius: 5px;
  `,
  welcomeMessageContent: css`
    padding: 1em;
  `,
  emptySpaceUnderSpin: css`
    height: 60px;
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

  renderWelcomeMessage = (welcomeMessage, values, handleChange) => (<>
    <Scrollbar className={styles.welcomeMessage}>
      <div className={styles.welcomeMessageContent}>
        <Text variant="p">{welcomeMessage}</Text>
      </div>
    </Scrollbar>
    <br />
    <InputGroup>
      <Checkbox checked={values['isAgreeChecked']} name="isAgreeChecked" onChange={handleChange}>
        I agree
        </Checkbox>
    </InputGroup>
  </>);

  render() {
    const {
      error,
      welcomeMessageExpected,
      welcomeMessage,
      onClose
    } = this.props;

    return (
      <Formik
        validationSchema={schema}
        onSubmit={this.handleSubmit}
        initialValues={{
          username: '',
          password: '',
          isAgreeChecked: false
        }}
      >
        {({
          values,
          errors,
          touched,
          handleChange,
          handleBlur
        }) => {
          const isLoginEnabled = welcomeMessage
            ? values['isAgreeChecked']
            : !welcomeMessageExpected;

          return (
            <Form>
              {formProps.map(({ label, field, type }) =>
                <FieldConstructor
                  key={field}
                  label={label}
                  required={true}
                  input={
                    <Input
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

              {(welcomeMessageExpected || welcomeMessage) ? (
                <Spin enable={!welcomeMessage}>
                  {welcomeMessage ?
                    this.renderWelcomeMessage(welcomeMessage, values, handleChange)
                    :
                    <div className={styles.emptySpaceUnderSpin}></div>
                  }
                </Spin>
              ) : null}

              <div className={styles.actionButtons}>
                {onClose && <Button intent="base" onClick={onClose} className={styles.cancelButton}>Cancel</Button>}
                <Button
                  className='meta-test__LoginFormBtn'
                  intent="primary"
                  type="submit"
                  disabled={!isLoginEnabled}
                >
                  Login
              </Button>
              </div>
            </Form>
          );
        }
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
    welcomeMessageExpected,
    welcomeMessage
  },
  ui: {
    fetchingAuth
  }
}) => ({
  authorizationRequired: implements_check_password && authorizationEnabled && !authorized,
  loaded,
  error,
  welcomeMessageExpected,
  welcomeMessage,
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
            <img src={window.tarantool_enterprise_core.logo} className={styles.logo} alt={'Tarantool logo'} />
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
    className='meta-test__LoginForm'
    title={'Authorization'}
    visible={visible}
    footer={null}
    onClose={onCancel}
    destroyOnClose={true}
  >
    <ModalInfoContainer>
      <ConnectedLogInForm {...props} onClose={onCancel} />
    </ModalInfoContainer>
  </Modal>
)

export default connect(mapStateToProps, { logIn })(SplashLogInForm);
