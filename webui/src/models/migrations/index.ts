/* eslint-disable @typescript-eslint/ban-ts-comment */
import { sample } from 'effector';
import { createGate } from 'effector-react';
import { TypeOf, array, object, record, string } from 'zod';

import { app } from 'src/models';
import { getMigrationsStates, migrationsMove, migrationsUp } from 'src/store/request/app.requests';

const schema = object({
  data: object({
    applied: record(array(string())),
  }),
});

export type Response = TypeOf<typeof schema>;

export const MigrationsGate = createGate();

const { notifySuccessEvent, notifyErrorEvent } = app;

export const $migrationsState = app.domain.createStore<Response['data'] | null>(null);

export const requestMigrationsStateEvent = app.domain.createEvent('request migrations state event');
export const upMigrationsEvent = app.domain.createEvent('up migrations event');
export const moveMigrationsEvent = app.domain.createEvent('up migrations event');

const requestMigrationsStateFx = app.domain.createEffect<void, Response>('request migrations state');
const upMigrationsFx = app.domain.createEffect<void, unknown>('up migrations');
const moveMigrationsFx = app.domain.createEffect<void, unknown>('up migrations');

export const $requestMigrationsStatePending = requestMigrationsStateFx.pending;
export const $upMigrationsPending = upMigrationsFx.pending;
export const $moveMigrationsPending = moveMigrationsFx.pending;

// init

// effects
requestMigrationsStateFx.use(() => getMigrationsStates().then((value) => schema.parse(value)));
upMigrationsFx.use(() => migrationsUp());
moveMigrationsFx.use(() => migrationsMove());

// links
$migrationsState.on(requestMigrationsStateFx.doneData, (_, payload) => payload.data).reset(MigrationsGate.close);

sample({
  clock: requestMigrationsStateEvent,
  target: requestMigrationsStateFx,
});

sample({
  clock: upMigrationsEvent,
  target: upMigrationsFx,
});

sample({
  clock: moveMigrationsEvent,
  target: moveMigrationsFx,
});

sample({
  clock: [moveMigrationsFx.done, upMigrationsFx.done, MigrationsGate.open],
  target: requestMigrationsStateEvent,
});

// notifications
sample({
  clock: upMigrationsFx.done.map(() => 'Success'),
  target: notifySuccessEvent,
});

sample({
  clock: moveMigrationsFx.done.map(() => 'Success'),
  target: notifySuccessEvent,
});

sample({
  clock: requestMigrationsStateFx.failData,
  target: notifyErrorEvent,
});

sample({
  clock: upMigrationsFx.failData,
  target: notifyErrorEvent,
});

sample({
  clock: moveMigrationsFx.failData,
  target: notifyErrorEvent,
});
