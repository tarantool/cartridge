import * as React from 'react';
import Modal from 'src/components/Modal';
import { connect } from 'react-redux';
import { changeFailover, setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';
import Button from 'src/components/Button';
import Switcher from 'src/components/Switcher';
import { css } from 'react-emotion';
import { SwitcherIconContainer, ModalInfoContainer, SwitcherInfoLine } from './styled'
import Text from './Text';
import { IconOk } from './Icon/icons/IconOk';
import { IconCancel } from './Icon/icons/IconCancel';

const description = `When enabled, every storage starts monitoring instance statuses.  
If a user-specified master goes down, a replica with the lowest UUID takes its place.
When the user-specified master comes back online, both roles are restored.`

class FailoverButton extends React.Component {
  render() {
    if (!this.props.clusterSelf.configured)
      return null;

    return (
      <React.Fragment>
        <Switcher
          onChange={() => this.props.dispatch(setVisibleFailoverModal(true))}
          checked={this.props.failover}
        >
          Failover
        </Switcher>
        <Modal
          title="Failover control"
          visible={this.props.showFailoverModal}
          onClose={() => this.props.dispatch(setVisibleFailoverModal(false))}
          footerControls={[
            <Button onClick={() => this.props.dispatch(setVisibleFailoverModal(false))}>Close</Button>,
            <Button
              intent='primary'
              onClick={() => this.props.dispatch(changeFailover({ enabled: !this.props.failover }))}
            >
              {this.props.failover ? 'Disable' : 'Enable'}
            </Button>
          ]}
        >
          <ModalInfoContainer>
            <SwitcherInfoLine>
              <Text variant={'basic'}>
                <SwitcherIconContainer>{this.props.failover ? <IconOk/> : <IconCancel/>}</SwitcherIconContainer>
                Failover <b>{this.props.failover ? 'enabled' : 'disabled'}</b>
              </Text>
            </SwitcherInfoLine>
            <SwitcherInfoLine>
              <Text variant={'basic'}>{description}</Text>
            </SwitcherInfoLine>
          </ModalInfoContainer>
        </Modal>
      </React.Fragment>
    );
  }
}

export default connect(({ app, ui }) => {
  return {
    clusterSelf: app.clusterSelf,
    failover: app.failover,
    showFailoverModal: ui.showFailoverModal
  }
})(FailoverButton);
