import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import { logIn } from 'src/store/actions/auth.actions';
import { Formik, Form } from 'formik'
import * as yup from 'yup'
import {
  Alert,
  Button,
  SplashModal,
  InputPassword,
  Checkbox,
  InputGroup,
  LabeledInput,
  Modal,
  Text,
  Spin,
  genericStyles
} from '@tarantool.io/ui-kit';
import logo from '../../assets/tarantool-logo-full.svg';

const schema = yup.object().shape({
  username: yup.string().required(),
  password: yup.string().required()
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
  `,
  requiredStar: css`
    color: red;
  `,
  welcomeMessage: css`
    height: 150px;
    padding: 12px;
    border: 1px solid #ddd;
    border-radius: 5px;
    overflow: auto;
  `,
  emptySpaceUnderSpin: css`
    height: 60px;
  `
};

class LogInForm extends React.Component {
  handleSubmit = async (values, actions) => {
    try {
      await this.props.logIn(values);
    } catch (e) {
      actions.setFieldError('common', e.message)
    } finally {
      actions.setSubmitting(false)
    }
  };

  renderWelcomeMessage = (welcomeMessage, values, handleChange) => (<>
    <div className={cx(styles.welcomeMessage, genericStyles.scrollbars)}>
      <Text variant="p">{welcomeMessage}</Text>
    </div>
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
              <LabeledInput
                label={<>Username<Text className={styles.requiredStar}>*</Text></>}
                value={values.username}
                onBlur={handleBlur}
                onChange={handleChange}
                name='username'
                error={touched.username && !!errors.username}
                message={touched.username && errors.username}
              />
              <LabeledInput
                label={<>Password<Text className={styles.requiredStar}>*</Text></>}
                value={values.password}
                onBlur={handleBlur}
                onChange={handleChange}
                inputComponent={InputPassword}
                name='password'
                error={touched.password && !!errors.password}
                message={touched.password && errors.password}
              />
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
                {onClose && (
                  <Button onClick={onClose} className={styles.cancelButton} size='l'>Cancel</Button>
                )}
                <Button
                  className='meta-test__LoginFormBtn'
                  intent="primary"
                  type="submit"
                  disabled={!isLoginEnabled}
                  size='l'
                >
                  Login
                </Button>
              </div>
            </Form>
          );
        }}
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
      <SplashModal
        className='meta-test__LoginFormSplash'
        title='Authorization'
        subTitle='Please, input your credentials'
        logo={logo}
      >
        <LogInForm {...props} />
      </SplashModal>
    )
    : null;
};

export const ModalLogInForm = ({ onCancel, visible, ...props }) => (
  <Modal
    className='meta-test__LoginForm'
    title='Authorization'
    visible={visible}
    footer={null}
    onClose={onCancel}
    destroyOnClose={true}
  >
    <ConnectedLogInForm {...props} onClose={onCancel} />
  </Modal>
)

export default connect(mapStateToProps, { logIn })(SplashLogInForm);
