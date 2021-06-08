import React from 'react';
import { connect } from 'react-redux';
import {
  Button,
  Dropdown,
  DropdownItem,
  SVGImage,
  Text
} from '@tarantool.io/ui-kit';
import { css, cx } from '@emotion/css';
import { ModalLogInForm } from 'src/components/LogInForm';
import { showAuthModal, hideAuthModal } from 'src/store/actions/auth.actions';
import userPic from './user.svg';

const styles = {
  box: css`
    display: flex;
    justify-content: flex-end;
    align-items: center;
  `,
  dropdown: css`
    cursor: pointer;
  `,
  userName: css`
    margin-right: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  button: css`
    flex-shrink: 0;
  `,
  authIcon: css`
    margin-right: 8px;
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

    if (authorized) {
      return (
        <Dropdown
          className={cx(styles.box, styles.dropdown, 'meta-test__LogoutBtn')}
          popoverClassName='meta-test__LogoutDropdown'
          items={[
            <DropdownItem onClick={this.sendLogOut}>Log out</DropdownItem>
          ]}
        >
          <SVGImage glyph={userPic} className={styles.authIcon} />
          <Text className={styles.userName}>{username}</Text>
        </Dropdown>
      )
    }

    return (
      <div className={styles.box}>
        {!authorized &&
        <Button
          className='meta-test__LoginBtn'
          text='Log in'
          intent='base'
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
