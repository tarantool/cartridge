import type { Event } from 'effector';

export type Maybe<T> = T | null | undefined;

export interface CreateTimeoutFxConfig<T extends unknown = void> {
  startEvent: Event<T>;
  stopEvent: Event<void>;
  effect: (counter: number, props: T | undefined | null) => Promise<void>;
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
