import * as React from 'react';
import Modal from 'src/components/Modal';
import { connect } from 'react-redux';
import { changeFailover, setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';
import Button from 'src/components/Button';
import Switcher from 'src/components/Switcher';
import { SwitcherIconContainer, ModalInfoContainer, SwitcherInfoLine } from './styled'
import Text from './Text';
import { IconOk } from './Icon/icons/IconOk';
import { IconCancel } from './Icon/icons/IconCancel';

const description = `When enabled, every storage starts monitoring instance statuses.  
If a user-specified master goes down, a replica with the lowest UUID takes its place.
When the user-specified master comes back online, both roles are restored.`

const FailoverButton = ({
  dispatch,
  failover,
  showFailoverModal
}) => (
  <React.Fragment>
    <Switcher
      onChange={() => dispatch(setVisibleFailoverModal(true))}
      checked={failover}
    >
      Failover
    </Switcher>
    <Modal
      title="Failover control"
      visible={showFailoverModal}
      onClose={() => dispatch(setVisibleFailoverModal(false))}
      footerControls={[
        <Button onClick={() => dispatch(setVisibleFailoverModal(false))}>Close</Button>,
        <Button
          intent='primary'
          onClick={() => dispatch(changeFailover({ enabled: !failover }))}
        >
          {failover ? 'Disable' : 'Enable'}
        </Button>
      ]}
    >
      <ModalInfoContainer>
        <SwitcherInfoLine>
          <Text variant={'basic'}>
            <SwitcherIconContainer>{failover ? <IconOk/> : <IconCancel/>}</SwitcherIconContainer>
            Failover <b>{failover ? 'enabled' : 'disabled'}</b>
          </Text>
        </SwitcherInfoLine>
        <SwitcherInfoLine>
          <Text variant={'basic'}>{description}</Text>
        </SwitcherInfoLine>
      </ModalInfoContainer>
    </Modal>
  </React.Fragment>
);

export default connect(({ app, ui }) => {
  return {
    failover: app.failover,
    showFailoverModal: ui.showFailoverModal
  }
})(FailoverButton);
