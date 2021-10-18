import { Event, Store, guard } from 'effector';

import { domain } from '../domain';
import { CreateTimeoutFxConfig } from '../types';
import { delay, not, trueL, voidL } from './common';

export const passResultOnEvent = <T>(_: unknown, pass: T): T => pass;

export const combineResultOnEvent = <S, T>(store: S, payload: T): S => ({ ...store, ...payload });

export const mapModalOpenedClosedEventPayload =
  (open: boolean) =>
  <T extends unknown>(props: T): { props: T; open: boolean } => ({ props, open });

export const createTimeoutFx = <T extends unknown = void>(
  name: string,
  { startEvent, stopEvent, effect, timeout }: CreateTimeoutFxConfig<T>
): [Store<boolean>, Event<void>] => {
  const tickEvent = domain.createEvent(`${name}.tick`);

  const $counter = domain
    .createStore(0, { name: `${name}.counter` })
    .on(tickEvent, (state) => state + 1)
    .reset([startEvent, stopEvent]);

  const $props = domain
    .createStore<T | null>(null, { name: `${name}.props` })
    .on(startEvent, (_, payload) => payload)
    .reset(stopEvent);

  const $isOn = domain
    .createStore(false, { name: `${name}.isOn` })
    .on(startEvent, trueL)
    .reset(stopEvent);

  const timerFx = domain
    .createEffect<{ $counter: number; $props: T | null }, void>(`${name}.timer`)
    .use(async ({ $counter, $props }): Promise<void> => {
      await effect($counter - 1, $props);
      await delay(typeof timeout === 'function' ? timeout() : timeout);
    });

  guard({
    clock: tickEvent,
    source: { $counter, $props },
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
