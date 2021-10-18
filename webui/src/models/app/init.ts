/* eslint-disable no-console */
import { forward } from 'effector';

import { AppGate, appClosedEvent, appOpenedEvent, notifyEvent, notifyFx } from '.';

forward({
  from: AppGate.open,
  to: appOpenedEvent,
});

forward({
  from: AppGate.close,
  to: appClosedEvent,
});

forward({
  from: notifyEvent,
  to: notifyFx,
});
