// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  guard,
  sample
} from 'effector';
import type { Effect } from 'effector';
import {
  getSchema,
  applySchema,
  checkSchema
} from '../../request/schema.requests';
import { getErrorMessage } from '../../../api';

export const schemaPageMount = createEvent<mixed>();
export const applyClick = createEvent<mixed>();
export const validateClick = createEvent<mixed>();
export const inputChange = createEvent<string>();

export const $initialSchema = createStore<string>('');
export const $changedSchema = createStore<string>('');
export const $error = createStore<string | null>(null);

export const applySchemaFx: Effect<string, void, Error> = createEffect(
  'submit schema',
  { handler: schema => applySchema(schema) }
);

export const getSchemaFx: Effect<void, string, Error> = createEffect(
  'get schema',
  { handler: () => getSchema() }
);

export const checkSchemaFx: Effect<string, void, Error> = createEffect(
  'submit schema',
  { handler: schema => checkSchema(schema) }
);

export const $form = createStoreObject({
  checking: checkSchemaFx.pending,
  loading: getSchemaFx.pending,
  uploading: applySchemaFx.pending,
  initialValue: $initialSchema,
  value: $changedSchema,
  error: $error
});

// init

$error
  .on(applySchemaFx.failData, (_, error) => getErrorMessage(error))
  .on(getSchemaFx.failData, (_, error) => getErrorMessage(error))
  .on(checkSchemaFx.doneData, (_, { cluster: { check_schema: { error } } }) => error)
  .on(checkSchemaFx.failData, (_, error) => getErrorMessage(error))
  .reset(applySchemaFx)
  .reset(getSchemaFx)
  .reset(checkSchemaFx)
  .reset(applySchemaFx.done)
  .reset(getSchemaFx.done)
  .reset(schemaPageMount);

checkSchemaFx.failData.watch(error => {
  getErrorMessage(error);
});

$initialSchema
  .on(getSchemaFx.doneData, (_, v) => v);

$changedSchema
  .on(getSchemaFx.doneData, (_, v) => v)
  .on(inputChange, (_, v) => v);

sample({
  source: $changedSchema,
  clock: applyClick,
  fn: s => s,
  target: applySchemaFx
});

sample({
  source: $changedSchema,
  clock: validateClick,
  fn: s => s,
  target: checkSchemaFx
});

guard({
  source: schemaPageMount,
  filter: $changedSchema.map(v => !v),
  target: getSchemaFx
});
