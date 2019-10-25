// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { turnAuth } from 'src/store/actions/auth.actions';
import {
  ConfirmModal,
  IconCancel,
  IconOk,
  Switcher,
  Text
} from '@tarantool.io/ui-kit';
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
