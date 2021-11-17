/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { NotificationSplashFixed } from '@tarantool.io/ui-kit';

import { app } from 'src/models';

const { $connectionAlive } = app;

export interface NetworkErrorSplashProps {
  onClose?: () => void;
}

const NetworkErrorSplash = ({ onClose }: NetworkErrorSplashProps) => {
  const connectionAlive = useStore($connectionAlive);

  if (connectionAlive) {
    return null;
  }

  return (
    <NotificationSplashFixed className="meta-test__NetworkErrorSplash" onClose={onClose}>
      Network connection problem or server disconnected
    </NotificationSplashFixed>
  );
};

export default NetworkErrorSplash;
