import React from 'react';
import { connect } from 'react-redux';
import { Form } from 'antd';
import Button from 'src/components/Button';
import Input from 'src/components/Input';
import { css } from 'emotion';
import { addUser } from 'src/store/actions/users.actions';

const styles = {
  error: css`
    min-height: 24px;
    margin: 0 0 24px;
    color: #f5222d;
  `
};

const formItemLayout = {
  labelAlign: 'left',
  labelCol: {
    span: 6
  },
  wrapperCol: {
    span: 18
  },
};

class UserAddForm extends React.Component {
  submit = evt => {
    const { addUser, form } = this.props;

    evt.preventDefault();

    form.validateFields((
      err,
      {
        username = '',
        fullname = '',
        email = '',
        password = ''
      }
    ) => {
      if (!err) {
        addUser({
          username,
          fullname,
          email,
          password
        });
      }
    });
  };

  render() {
    const {
      error,
      loading,
      form: {
        getFieldDecorator
      }
    } = this.props;

    return (
      <Form onSubmit={this.submit}>
        <Form.Item label="User name" {...formItemLayout}>
          {getFieldDecorator('username', {
            rules: [{ required: true, message: 'Fill user name field' }]
          })(
            <Input autoFocus />
          )}
        </Form.Item>
        <Form.Item label="Password" {...formItemLayout}>
          {getFieldDecorator('password', {
            rules: [
              { required: true, message: 'Fill password field' }
            ]
          })(
            <Input type="password" />
          )}
        </Form.Item>
        <Form.Item label="Full name" {...formItemLayout}>
          {getFieldDecorator('fullname')(
            <Input />
          )}
        </Form.Item>
        <Form.Item label="E-mail" {...formItemLayout}>
          {getFieldDecorator('email', {
            rules: [
              { type: 'email', message: 'Please input a valid E-mail' }
            ]
          })(
            <Input />
          )}
        </Form.Item>
        <p className={styles.error}>{error}</p>
        <Button type="primary" htmlType="submit" loading={loading}>Add</Button>
      </Form>
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
)(Form.create()(UserAddForm));

export default connectedForm;
