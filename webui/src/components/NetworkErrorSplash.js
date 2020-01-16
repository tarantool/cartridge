// @flow
import * as React from 'react'
import { NotificationSplashFixed } from '@tarantool.io/ui-kit';
import { connect } from 'react-redux';
import { type State } from 'src/store/rootReducer';

type NetworkErrorSplashProps = {
  visible: boolean,
  onClose?: () => void
};

export const NetworkErrorSplash = (
  {
    visible,
    onClose
  }: NetworkErrorSplashProps
) => {
  if (!visible)
    return false;

  return (
    <NotificationSplashFixed onClose={onClose}>
      Network connection problem or server disconnected
    </NotificationSplashFixed>
  );
}

const mapStateToProps = (state: State) => ({
  visible: !state.app.connectionAlive
});

export default connect(mapStateToProps)(NetworkErrorSplash);
