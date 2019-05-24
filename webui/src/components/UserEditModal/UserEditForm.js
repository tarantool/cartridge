import React from 'react';
import { connect } from 'react-redux';
import { Form } from 'antd';
import Button from 'src/components/Button';
import Input from 'src/components/Input';
import { css } from 'emotion';
import { editUser } from 'src/store/actions/users.actions';

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

class UserEditForm extends React.Component {
  submit = evt => {
    const { editUser, form, username } = this.props;

    evt.preventDefault();

    form.validateFields((
      err,
      {
        fullname = '',
        email = '',
        password = ''
      }
    ) => {
      if (!err) {
        editUser({
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
      },
      username,
      fullname,
      email
    } = this.props;

    return (
      <Form onSubmit={this.submit}>
        <Form.Item label="User name" {...formItemLayout}>
          <Input autoFocus disabled value={username} />
        </Form.Item>
        <Form.Item label="New password" {...formItemLayout}>
          {getFieldDecorator('password')(
            <Input type="password" autoFocus />
          )}
        </Form.Item>
        <Form.Item label="Full name" {...formItemLayout}>
          {getFieldDecorator('fullname', { initialValue: fullname || '' })(
            <Input />
          )}
        </Form.Item>
        <Form.Item label="E-mail" {...formItemLayout}>
          {getFieldDecorator('email', {
            initialValue: email || '',
            rules: [
              { type: 'email', message: 'Please input a valid E-mail' }
            ]
          })(
            <Input />
          )}
        </Form.Item>
        <p className={styles.error}>{error}</p>
        <Button type="primary" htmlType="submit" loading={loading}>Save</Button>
      </Form>
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
)(Form.create()(UserEditForm));

export default connectedForm;
