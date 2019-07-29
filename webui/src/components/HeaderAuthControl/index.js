import React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import { css } from 'emotion';
import { ModalLogInForm } from 'src/components/LogInForm';
import { showAuthModal, hideAuthModal } from 'src/store/actions/auth.actions';

const styles = {
  box: css`
    display: flex;
    justify-content: flex-end;
    align-items: center;
    width: 200px;
    margin: 13px 30px 0 auto;
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
  `
};

class HeaderAuthControl extends React.Component {
  sendLogOut = () => window.tarantool_enterprise_core.dispatch('cluster:logout');

  render() {
    const {
      implements_check_password,
      authorizationEnabled,
      username,
      authorized,
      authModalVisible,
      showAuthModal,
      hideAuthModal
    } = this.props;

    if (!implements_check_password)
      return null;

    if (authorizationEnabled & !authorized)
      return null;

    return (
      <div className={styles.box}>
        <span class={styles.userName}>{username}</span>
        {
          authorized
            ? (
              <Button
                className={styles.button}
                size="small"
                shape="circle"
                onClick={this.sendLogOut}
                icon="logout"
                title="Log out"
              />
            )
            : (
              <Button
                className={styles.button}
                size="small"
                onClick={showAuthModal}
                icon="user"
                title="Log in"
                text="Log in"
              >
                Log in
              </Button>
            )
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
