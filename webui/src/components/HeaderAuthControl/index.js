import React, { useCallback } from 'react';
import { connect } from 'react-redux';
import { css, cx } from '@emotion/css';
import { useCore } from '@tarantool.io/frontend-core';
import { Button, Dropdown, DropdownItem, SVGImage, Text } from '@tarantool.io/ui-kit';

import { ModalLogInForm } from 'src/components/LogInForm';
import { hideAuthModal, showAuthModal } from 'src/store/actions/auth.actions';

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
    height: 24px;
    width: 24px;
  `,
};

const HeaderAuthControl = (props) => {
  const { implements_check_password, username, authorized, authModalVisible, showAuthModal, hideAuthModal } = props;

  const core = useCore();

  const sendLogOut = useCallback(() => {
    core && core.dispatch('cluster:logout');
  }, [core]);

  if (!implements_check_password) return null;

  if (authorized) {
    return (
      <Dropdown
        className={cx(styles.box, styles.dropdown, 'meta-test__LogoutBtn')}
        popoverClassName="meta-test__LogoutDropdown"
        items={[
          <DropdownItem key={0} onClick={sendLogOut}>
            Log out
          </DropdownItem>,
        ]}
      >
        <SVGImage glyph={userPic} className={styles.authIcon} />
        <Text className={styles.userName}>{username}</Text>
      </Dropdown>
    );
  }

  return (
    <div className={styles.box}>
      {!authorized && (
        <Button className="meta-test__LoginBtn" text="Log in" intent="base" onClick={() => showAuthModal()} />
      )}
      <ModalLogInForm visible={authModalVisible} onCancel={hideAuthModal} />
    </div>
  );
};

const mapStateToProps = ({
  app: {
    authParams: { implements_check_password },
  },
  auth: { authorizationEnabled, username, authorized, authModalVisible },
}) => ({
  implements_check_password,
  authorizationEnabled,
  username,
  authorized,
  authModalVisible,
});

export default connect(mapStateToProps, { showAuthModal, hideAuthModal })(HeaderAuthControl);
