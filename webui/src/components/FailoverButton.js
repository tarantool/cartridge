// @flow
import React from 'react';
import { connect } from 'react-redux';
import { Button } from '@tarantool.io/ui-kit';

import { setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';

import FailoverModal from './FailoverModal';

type FailoverButtonProps = {
  mode: string,
  visible: boolean,
  showFailoverModal: boolean,
  dispatch: (action: any) => void,
};

const FailoverButton = ({ dispatch, mode, showFailoverModal, visible }: FailoverButtonProps) => {
  if (!visible) return null;

  return (
    <React.Fragment>
      <Button className="meta-test__FailoverButton" onClick={() => dispatch(setVisibleFailoverModal(true))} size="l">
        {`Failover: ${mode}`}
      </Button>
      {showFailoverModal && <FailoverModal />}
    </React.Fragment>
  );
};

export default connect(({ app, ui, clusterPage: { failoverMode } }) => {
  return {
    mode: failoverMode ? failoverMode : app.failover_params.mode,
    showFailoverModal: ui.showFailoverModal,
    visible: !!(app.clusterSelf && app.clusterSelf.configured),
  };
})(FailoverButton);
