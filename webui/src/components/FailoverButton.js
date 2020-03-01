import * as React from 'react';
import { connect } from 'react-redux';
import { changeFailover, setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';
import {
  Button,
  IconOk,
  IconCancel,
  Modal,
  Switcher,
  Text
} from '@tarantool.io/ui-kit';
import { SwitcherIconContainer, ModalInfoContainer, SwitcherInfoLine } from './styled'

const description = `When enabled, every storage starts monitoring instance statuses.
If a user-specified master goes down, a replica with the lowest UUID takes its place.
When the user-specified master comes back online, both roles are restored.`

const FailoverButton = ({
  dispatch,
  failover,
  showFailoverModal,
  visible
}) => {
  if (!visible)
    return null;

  return (
    <React.Fragment>
      <Switcher
        className='meta-test__FailoverButton'
        onChange={() => dispatch(setVisibleFailoverModal(true))}
        checked={failover.enabled}
      >
        Failover
      </Switcher>
      <Modal
        className='meta-test__FailoverModal'
        title="Failover control"
        visible={showFailoverModal}
        onClose={() => dispatch(setVisibleFailoverModal(false))}
        footerControls={[
          <Button
            onClick={() => dispatch(setVisibleFailoverModal(false))}
          >
            Close
          </Button>,
          <Button
            className='meta-test__SubmitButton'
            intent='primary'
            onClick={() => dispatch(changeFailover({ enabled: !failover.enabled }))}
          >
            {failover.enabled ? 'Disable' : 'Enable'}
          </Button>
        ]}
      >
        <ModalInfoContainer>
          <SwitcherInfoLine>
            <Text variant={'basic'}>
              <SwitcherIconContainer>{failover.enabled ? <IconOk/> : <IconCancel/>}</SwitcherIconContainer>
              Failover <b>{failover.enabled ? 'enabled' : 'disabled'}</b>
            </Text>
          </SwitcherInfoLine>
          <SwitcherInfoLine>
            <Text variant={'basic'}>{description}</Text>
          </SwitcherInfoLine>
        </ModalInfoContainer>
      </Modal>
    </React.Fragment>
  );
};

export default connect(({ app, ui }) => {
  return {
    failover: app.failover,
    showFailoverModal: ui.showFailoverModal,
    visible: !!(app.clusterSelf && app.clusterSelf.configured)
  }
})(FailoverButton);
