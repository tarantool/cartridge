/* eslint-disable import/no-duplicates */
import { createEvent } from 'effector';

import {
  combineResultOnEvent,
  createTimeoutFx,
  mapErrorWithTitle,
  mapModalOpenedClosedEventPayload,
  passErrorMessageOnEvent,
  passResultOnEvent,
  passResultPathOnEvent,
} from './effector';

describe('models.app.utils', () => {
  it('mapErrorWithTitle', () => {
    const error = new Error();
    expect(mapErrorWithTitle('title')(error)).toStrictEqual({ error, title: 'title' });
  });
  it('passResultOnEvent', () => {
    expect(passResultOnEvent(null, 0)).toBe(0);
    expect(passResultOnEvent(null, 1)).toBe(1);
  });
  it('passResultPathOnEvent', () => {
    expect(passResultPathOnEvent<{ title: string }>('title')(null, { title: 'title' })).toBe('title');
  });
  it('passErrorMessageOnEvent', () => {
    expect(passErrorMessageOnEvent(null, new Error('@error'))).toBe('@error');
  });
  it('combineResultOnEvent', () => {
    expect(combineResultOnEvent({ a: 1, b: 2 }, { b: 3 })).toEqual({ a: 1, b: 3 });
  });
  it('mapModalOpenedClosedEventPayload', () => {
    expect(mapModalOpenedClosedEventPayload(true)(null)).toEqual({ props: null, open: true });
    expect(mapModalOpenedClosedEventPayload(false)(null)).toEqual({ props: null, open: false });
  });
  it('createTimeoutFx', async () => {
    const delay = (ms: number) => new Promise((resolve) => void setTimeout(() => resolve(void 0), ms));
    const startEvent = createEvent('start');
    const stopEvent = createEvent('stop');

    const effect = jest.fn(() => Promise.resolve());

    const timer = createTimeoutFx('name', {
      startEvent,
      stopEvent,
      effect,
      timeout: 10,
    });

    expect(timer).toBeDefined();
    expect(effect).toBeCalledTimes(0);

    startEvent();

    expect(effect).toBeCalledTimes(1);

    await delay(5);
    expect(effect).toBeCalledTimes(1);
    await delay(10);
    expect(effect).toBeCalledTimes(2);
    await delay(20);
    expect(effect).toBeCalledTimes(4);

    stopEvent();
    expect(effect).toBeCalledTimes(4);
    await delay(20);
    expect(effect).toBeCalledTimes(4);

    expect(effect.mock.calls).toEqual([
      [0, null, null],
      [1, null, null],
      [2, null, null],
      [3, null, null],
    ]);
  });
});
