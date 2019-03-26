import React from 'react';
import { connect } from 'react-redux';
import { Form, Icon, Input, Button } from 'antd';
import { css } from 'emotion';
import { logIn } from 'src/store/actions/auth.actions';

const styles = {
  formWrap: css`
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
  `,
  form: css`
    width: 100%;
    max-width: 300px;
  `,
  submitBtn: css`
    width: 100%;
  `,
  error: css`
    color: #f5222d;
  `
};

class AuthForm extends React.Component {
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
      loading
    } = this.props;

    return (
      <div className={styles.formWrap}>
        <h1>Authorization</h1>
        <p>Who are you?</p>
        <Form onSubmit={this.handleSubmit} className={styles.form}>
          <Form.Item>
            {getFieldDecorator('username', {
              rules: [{ required: true, message: 'Fill user name field' }]
            })(
              <Input
                prefix={<Icon type="user" />}
                placeholder="User name"
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
              loading={loading}
            >
              Log in
            </Button>
          </Form.Item>
        </Form>
        {!!error && <p className={styles.error}>{error}</p>}
      </div>
    );
  }
}

const mapStateToProps = ({
  auth: {
    error,
    loading
  }
}) => ({
  loading,
  error
});

export default connect(mapStateToProps, { logIn })(Form.create()(AuthForm));
