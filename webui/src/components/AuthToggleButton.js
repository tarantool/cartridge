// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import { turnAuth } from 'src/store/actions/auth.actions';
import Switcher from './Switcher';
import { ConfirmModal } from './Modal';
import styled from 'react-emotion';
import { IconOk } from './Icon/icons/IconOk';
import { IconCancel } from './Icon/icons/IconCancel';
import Text from './Text';
import { SwitcherIconContainer, ModalInfoContainer, SwitcherInfoLine } from './styled'


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
      authorizationEnabled,
      fetchingAuth,
      className
    } = this.props;

    const { visible } = this.state

    return implements_check_password ?
      (
        <React.Fragment>
          <Switcher
            onChange={this.showModal}
            checked={authorizationEnabled}
            className={className}
          >
            Auth
          </Switcher>
          <ConfirmModal
            visible={visible}
            confirmText={authorizationEnabled ? 'Disable' : 'Enable'}
            onConfirm={this.handleClick}
            onCancel={this.hideModal}
            title={'Authorization'}
          >
            <ModalInfoContainer>
              <SwitcherInfoLine>
                <Text variant={'basic'}>
                  <SwitcherIconContainer>{authorizationEnabled ? <IconOk/> : <IconCancel/>}</SwitcherIconContainer>
                  Authorization <b>{authorizationEnabled ? 'enabled' : 'disabled'}</b>
                </Text>
              </SwitcherInfoLine>
              <SwitcherInfoLine>
                <Text variant={'basic'}>
                  When you enable this option, an authorization page will be available to you each time the session ends
                </Text>
              </SwitcherInfoLine>
            </ModalInfoContainer>
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
