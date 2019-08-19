import React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import { css, cx } from 'emotion';
import { ModalLogInForm } from 'src/components/LogInForm';
import { showAuthModal, hideAuthModal } from 'src/store/actions/auth.actions';
import Text from '../Text';
import { IconUser } from '../Icon/icons/IconUser';
import Dropdown from '../Dropdown';

const styles = {
  box: css`
    display: flex;
    justify-content: flex-end;
    align-items: center;
    margin: 0 0 0 24px;
  `,
  userName: css`
    margin-right: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: white;
    width: 
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
  showDropdown = () => this.setState({ showDropdown: true })
  hideDropdown = () => this.setState({ showDropdown: false })

  state = {
    showDropdown: false
  }


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

    const {
      showDropdown
    } = this.state

    if (!implements_check_password)
      return null;

    if (username) {
      return (
        <Dropdown
          className={cx(styles.box, css`cursor: pointer`)}
          items={[{ text: 'Log out', onClick: this.sendLogOut }]}
        >
          <div
            className={styles.authIcon}

          >
            <IconUser/>
          </div>
          <span className={styles.userName}><Text variant={'basic'}>{username}</Text></span>
        </Dropdown>
      )
    }

    return (
      <div className={styles.box}>
        {!authorized && <Button text={'Log in'} intent={'base'} onClick={() => showAuthModal()} />}
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
