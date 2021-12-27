const AUTH_TRIGGER_SESSION_KEY = 'tt.auth.trigger';

import { app } from 'src/models';

const { showAuthSessionChangeModalEvent } = app;
const { tryNoCatch } = app.utils;

export const trigger = () => {
  tryNoCatch(() => localStorage.setItem(AUTH_TRIGGER_SESSION_KEY, `${Math.random()}`));
};

export const init = () => {
  tryNoCatch(() =>
    window.addEventListener('storage', (e: StorageEvent) => {
      if (e && e.key === AUTH_TRIGGER_SESSION_KEY) {
        showAuthSessionChangeModalEvent();
      }
    })
  );
};
