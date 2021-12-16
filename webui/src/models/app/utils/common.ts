import type { SyntheticEvent } from 'react';
import { compose, equals, groupBy, map, not, omit, pipe, prop, uniq } from 'ramda';

export { uniq, prop, groupBy, equals, compose, map, not, pipe, omit };

export const noop = (): void => void 0;

export const voidL = noop;

export const undefinedL = noop;

export const zeroL = (): number => 0;

export const trueL = (): boolean => true;

export const falseL = (): boolean => false;

export const exists = <T>(value: T | null | undefined): value is T => value !== undefined && value !== null;

export const compact = <T>(list: (T | undefined | null | false)[]): T[] => list.filter(Boolean) as T[];

export const some = (list: unknown[]): boolean => list.some(Boolean);

export const delay = (ms: number): Promise<void> => new Promise((resolve) => void setTimeout(() => resolve(), ms));

export const parseIntSafe = (value: unknown | undefined | null, def = 0, radix = 10): number => {
  const result = parseInt(`${value}` || `${def}`, radix);
  return Number.isNaN(result) ? def : result;
};

export const parseFloatSafe = (value: unknown | undefined | null, def = 0): number => {
  const result = parseFloat(`${value}` || `${def}`);
  return Number.isNaN(result) ? def : result;
};

const BYTE_UNITS = ['KiB', 'MiB', 'GiB', 'TiB', 'PiB'];

export const getReadableBytes = (size: number): string => {
  let bytes = size;
  let i = -1;
  do {
    bytes = bytes / 1024;
    i++;
  } while (bytes > 1024);

  return `${Math.max(bytes, 0.1).toFixed(1)} ${BYTE_UNITS[i]}`;
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const isMaybe = (data: any): data is undefined | null => data === undefined || data === null;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const isError = (data: any): data is Error => data instanceof Error;

export const upFirst = (value: string) =>
  value.length > 0 ? value.substring(0, 1).toUpperCase() + value.substring(1) : value;

export const upCase = (value: string | number | null | undefined) => {
  if (isMaybe(value)) {
    return '';
  }

  return `${value}`.toUpperCase();
};

export const lowCase = (value: string | number | null | undefined) => {
  if (isMaybe(value)) {
    return '';
  }

  return `${value}`.toLowerCase();
};

export const preventDefault = (e: SyntheticEvent) => void e.preventDefault();

export const stopPropagation = (e: SyntheticEvent) => void e.stopPropagation();
