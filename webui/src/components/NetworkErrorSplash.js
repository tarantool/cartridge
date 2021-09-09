// @flow
import React from 'react';
import { connect } from 'react-redux';
import { NotificationSplashFixed } from '@tarantool.io/ui-kit';

import type { State } from 'src/store/rootReducer';

type NetworkErrorSplashProps = {
  visible: boolean,
  onClose?: () => void,
};

const NetworkErrorSplash = ({ visible, onClose }: NetworkErrorSplashProps) => {
  if (!visible) return false;

  return (
    <NotificationSplashFixed className="meta-test__NetworkErrorSplash" onClose={onClose}>
      Network connection problem or server disconnected
    </NotificationSplashFixed>
  );
};

const mapStateToProps = (state: State) => ({
  visible: !state.app.connectionAlive,
});

export default connect(mapStateToProps)(NetworkErrorSplash);
