import { createEffect, createEvent, createStore, guard } from 'effector';
import type { Event, Store } from 'effector';

import { getErrorMessage } from 'src/api/utils';

import type { CreateTimeoutFxConfig } from '../types';
import { delay, not, trueL, voidL } from './common';

export const passResultOnEvent = <T>(_: unknown, pass: T): T => pass;

// eslint-disable-next-line @typescript-eslint/ban-types
export const passResultPathOnEvent = <T extends object, K extends keyof T = keyof T>(path: K) => {
  return (_: unknown, pass: T): T[K] => pass[path];
};

export const passErrorMessageOnEvent = (_: unknown, error: Error): string => getErrorMessage(error);

export const mapErrorWithTitle = (title: string) => (error: Error) => ({ error, title });

export const combineResultOnEvent = <S, T>(store: S, payload: T): S => ({ ...store, ...payload });

export const mapModalOpenedClosedEventPayload =
  (open: boolean) =>
  <T extends unknown>(props: T): { props: T; open: boolean } => ({ props, open });

export const createTimeoutFx = <T extends unknown = void, S extends unknown = void>(
  name: string,
  { startEvent, stopEvent, effect, timeout, source }: CreateTimeoutFxConfig<T, S>
): [Store<boolean>, Event<void>] => {
  const tickEvent = createEvent(`${name}.tick`);

  const $counter = createStore(0, { name: `${name}.counter` })
    .on(tickEvent, (state) => state + 1)
    .reset([startEvent, stopEvent]);

  const $props = createStore<T | null>(null, { name: `${name}.props` })
    .on(startEvent, (_, payload) => payload)
    .reset(stopEvent);

  const $isOn = createStore(false, { name: `${name}.isOn` })
    .on(startEvent, trueL)
    .reset(stopEvent);

  const timerFx = createEffect<{ $counter: number; $props: T | null; source?: S }, void>(`${name}.timer`).use(
    async ({ $counter, $props, source }): Promise<void> => {
      await effect($counter - 1, $props, source ?? null);
      await delay(typeof timeout === 'function' ? timeout() : timeout);
    }
  );

  guard({
    clock: tickEvent,
    source: source ? { $counter, $props, source } : { $counter, $props },
    filter: $isOn,
    target: timerFx,
  });

  guard({
    source: startEvent.map(voidL),
    filter: timerFx.pending.map(not),
    target: tickEvent,
  });

  guard({
    source: timerFx.doneData,
    filter: $isOn,
    target: tickEvent,
  });

  return [$isOn, tickEvent];
};
