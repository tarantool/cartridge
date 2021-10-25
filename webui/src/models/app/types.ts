import type { Event, Store } from 'effector';
import type { NumberSchema, ObjectSchema, StringSchema } from 'yup';

export type Maybe<T> = T | null | undefined;
export type { NumberSchema, ObjectSchema, StringSchema };

export interface CreateTimeoutFxConfig<T extends unknown = void, S extends unknown = void> {
  startEvent: Event<T>;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  stopEvent: Event<any>;
  source?: Store<S>;
  effect: (counter: number, props: T | undefined | null, store: S | null) => Promise<void>;
  timeout: number | (() => number);
}

export interface AppNotifyPayload {
  title: string;
  message: string;
  details?: Maybe<string>;
  type?: 'success' | 'error';
  timeout?: number;
}

export interface AppNotifyErrorPayloadProps {
  error: Error;
  title?: string;
  timeout?: number;
}

export type AppNotifyErrorPayload = Error | AppNotifyErrorPayloadProps;
