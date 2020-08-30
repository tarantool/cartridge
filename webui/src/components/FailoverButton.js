// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';
import { Button } from '@tarantool.io/ui-kit';
import FailoverModal from './FailoverModal';

type FailoverButtonProps = {
  mode: string,
  visible: boolean,
  showFailoverModal: boolean,
  dispatch: (action: any) => void
}

const FailoverButton = (
  {
    dispatch,
    mode,
    showFailoverModal,
    visible
  }: FailoverButtonProps
) => {
  if (!visible)
    return null;

  return (
    <React.Fragment>
      <Button
        className='meta-test__FailoverButton'
        onClick={() => dispatch(setVisibleFailoverModal(true))}
        size='l'
      >
        {`Failover: ${mode}`}
      </Button>
      {showFailoverModal && <FailoverModal />}
    </React.Fragment>
  );
};

export default connect(({ app, ui }) => {
  return {
    mode: app.failover_params.mode,
    showFailoverModal: ui.showFailoverModal,
    visible: !!(app.clusterSelf && app.clusterSelf.configured)
  }
})(FailoverButton);
