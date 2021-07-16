// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { css } from '@emotion/css';
import styled from '@emotion/styled';
import {
  ConfirmModal,
  IconCancel,
  IconOk,
  Switcher,
  Text
} from '@tarantool.io/ui-kit';
import { turnAuth } from 'src/store/actions/auth.actions';

const styles = {
  paragraph: css`
    margin: 0 0 24px;
  `
};

const SwitcherIconContainer = styled.span`
  display: inline-block;
  margin-right: 8px;
`

type AuthToggleButtonProps = {
  implements_check_password: boolean,
  authorizationEnabled: boolean,
  fetchingAuth: boolean,
  turnAuth: (enable: boolean) => void,
  className?: string,
};

class AuthToggleButton extends React.Component<AuthToggleButtonProps, {visible: boolean}> {
  state = {
    visible: false
  }

  handleClick = () => {
    this.props.turnAuth(!this.props.authorizationEnabled);
    this.hideModal()
  };

  showModal = () => this.setState({ visible: true })
  hideModal = () => this.setState({ visible: false })

  render() {
    const {
      implements_check_password,
      authorizationEnabled
    } = this.props;

    const { visible } = this.state

    return implements_check_password ?
      (
        <React.Fragment>
          <Switcher
            className='meta-test__AuthToggle'
            onChange={this.showModal}
            checked={authorizationEnabled}
          >
            Auth
          </Switcher>
          <ConfirmModal
            className='meta-test__ConfirmModal'
            visible={visible}
            confirmText={authorizationEnabled ? 'Disable' : 'Enable'}
            onConfirm={this.handleClick}
            onCancel={this.hideModal}
            title={'Authorization'}
          >
            <Text tag='p' className={styles.paragraph}>
              <SwitcherIconContainer>{authorizationEnabled ? <IconOk/> : <IconCancel/>}</SwitcherIconContainer>
                  Authorization <b>{authorizationEnabled ? 'enabled' : 'disabled'}</b>
            </Text>
            <Text tag='p' className={styles.paragraph}>
                  When you enable this option, an authorization page will be available to you each time the session ends
            </Text>
          </ConfirmModal>
        </React.Fragment>
      ) :
      null;
  }
}

const mapStateToProps = ({
  app: {
    authParams: {
      implements_check_password
    }
  },
  auth: {
    authorizationEnabled
  },
  ui: {
    fetchingAuth
  }
}, { className }) => ({
  implements_check_password,
  authorizationEnabled,
  fetchingAuth,
  className

});

export default connect(mapStateToProps, { turnAuth })(AuthToggleButton);
