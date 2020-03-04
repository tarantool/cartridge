import React from 'react';
import { connect } from 'react-redux';
import {
  Button,
  Dropdown,
  DropdownItem,
  IconUser,
  Text
} from '@tarantool.io/ui-kit';
import { css, cx } from 'emotion';
import { ModalLogInForm } from 'src/components/LogInForm';
import { showAuthModal, hideAuthModal } from 'src/store/actions/auth.actions';

const styles = {
  box: css`
    display: flex;
    justify-content: flex-end;
    align-items: center;
    margin: 0 0 0 24px;
  `,
  dropdown: css`
    cursor: pointer;
  `,
  userName: css`
    margin-right: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: white;
  `,
  button: css`
    flex-shrink: 0;
  `,
  authIcon: css`
    margin-right: 8px;
    cursor: pointer;
  `
};

class HeaderAuthControl extends React.Component {
  sendLogOut = () => window.tarantool_enterprise_core.dispatch('cluster:logout');

  render() {
    const {
      implements_check_password,
      username,
      authorized,
      authModalVisible,
      showAuthModal,
      hideAuthModal
    } = this.props;


    if (!implements_check_password)
      return null;

    if (username) {
      return (
        <Dropdown
          className={cx(styles.box, styles.dropdown, 'meta-test__LogoutBtn')}
          items={[
            <DropdownItem onClick={this.sendLogOut}>Log out</DropdownItem>
          ]}
        >
          <div className={styles.authIcon}>
            <IconUser/>
          </div>
          <span className={styles.userName}><Text variant={'basic'}>{username}</Text></span>
        </Dropdown>
      )
    }

    return (
      <div className={styles.box}>
        {!authorized &&
        <Button
          className='meta-test__LoginBtn'
          text={'Log in'}
          intent={'base'}
          onClick={() => showAuthModal()}
        />
        }
        <ModalLogInForm
          visible={authModalVisible}
          onCancel={hideAuthModal}
        />
      </div>
    );
  }
}

const mapStateToProps = ({
  app: {
    authParams: {
      implements_check_password
    }
  },
  auth: {
    authorizationEnabled,
    username,
    authorized,
    authModalVisible
  }
}) => ({
  implements_check_password,
  authorizationEnabled,
  username,
  authorized,
  authModalVisible
});

export default connect(mapStateToProps, { showAuthModal, hideAuthModal })(HeaderAuthControl);
