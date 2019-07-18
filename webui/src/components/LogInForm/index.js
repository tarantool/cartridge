import React from 'react';
import { connect } from 'react-redux';
import { Form, Icon, Input } from 'antd';
import { css } from 'emotion';
import { logIn } from 'src/store/actions/auth.actions';
import Modal from 'src/components/Modal';
import Button from 'src/components/Button';

const styles = {
  formWrap: css`
    position: absolute;
    left: 0;
    top: 50px;
    bottom: 0;
    z-index: 1;
    background: #d9d9d9;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    width: 100%;
    min-height: 100%;
    padding-top: 20px;
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
    min-height: 24px;
    margin: 0;
    color: #f5222d;
  `
};

class LogInForm extends React.Component {
  handleSubmit = e => {
    e.preventDefault();
    this.props.form.validateFields((err, { username, password }) => {
      if (!err) {
        this.props.logIn({ username, password });
      }
    });
  };

  render() {
    const {
      error,
      form: { getFieldDecorator },
      fetchingAuth
    } = this.props;

    return (
      <Form onSubmit={this.handleSubmit} className={styles.form}>
        <Form.Item>
          {getFieldDecorator('username', {
            rules: [{ required: true, message: 'Fill user name field' }]
          })(
            <Input
              prefix={<Icon type="user" />}
              placeholder="User name"
              autoFocus
            />
          )}
        </Form.Item>
        <Form.Item>
          {getFieldDecorator('password', {
            rules: [
              { required: true, message: 'Fill password field' }
            ]
          })(
            <Input
              prefix={<Icon type="lock" />}
              type="password"
              placeholder="Password"
            />
          )}
        </Form.Item>
        <Form.Item>
          <Button
            className={styles.submitBtn}
            type="primary"
            htmlType="submit"
            loading={fetchingAuth}
          >
            Log in
          </Button>
        </Form.Item>
        <p className={styles.error}>{error}</p>
      </Form>
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
    error
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

const ConnectedLogInForm = connect(mapStateToProps, { logIn })(Form.create()(LogInForm));

const SplashLogInForm = ({
  authorizationRequired,
  loaded,
  ...props
}) => {
  return loaded && authorizationRequired
    ? (
      <div className={styles.formWrap}>
        <h1>Authorization</h1>
        <p>Please, input your credentials</p>
        <LogInForm {...props} />
      </div>
    )
    : null;
};

export const ModalLogInForm = ({ onCancel, visible, ...props }) => (
  <Modal
    title="Authorization"
    visible={visible}
    width={350}
    footer={null}
    onCancel={onCancel}
    destroyOnClose={true}
  >
    <ConnectedLogInForm {...props} />
  </Modal>
)

export default connect(mapStateToProps, { logIn })(Form.create()(SplashLogInForm));
