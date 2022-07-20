export type FailoverMode = 'disabled' | 'eventual' | 'stateful';
export type FailoverStateProvider = 'tarantool' | 'etcd2';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const isFailoverMode = (mode: any): mode is FailoverMode =>
  mode === 'disabled' || mode === 'eventual' || mode === 'stateful';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const toFailoverMode = (mode: any): FailoverMode => (isFailoverMode(mode) ? mode : 'disabled');

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const isFailoverStateProvider = (provider: any): provider is FailoverStateProvider =>
  provider === 'tarantool' || provider === 'etcd2';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const toFailoverStateProvider = (provider: any): FailoverStateProvider =>
  isFailoverStateProvider(provider) ? provider : 'tarantool';
