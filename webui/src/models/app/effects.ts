import { domain } from './domain';
import type { AppNotifyPayload, Maybe } from './types';

export const notifyFx = domain.createEffect<Maybe<AppNotifyPayload>, void>('notify', {
  handler: (props) => {
    if (!props) {
      return;
    }

    const { title, message, type = 'success', timeout = 5000, details } = props;
    window.tarantool_enterprise_core.notify({
      title,
      message,
      type,
      timeout,
      details,
    });
  },
});

export const consoleLogFx = domain.createEffect<unknown, void>('consol.log', {
  handler: (props) => {
    console.log(props);
  },
});
