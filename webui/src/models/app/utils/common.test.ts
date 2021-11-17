import {
  compact,
  delay,
  exists,
  falseL,
  getReadableBytes,
  isError,
  noop,
  parseFloatSafe,
  parseIntSafe,
  some,
  trueL,
  undefinedL,
  upFirst,
  voidL,
  zeroL,
} from './common';

describe('models.app.utils', () => {
  it('noop/voidL/undefinedL/zeroL/falseL/trueL', () => {
    expect(noop()).toBeUndefined();
    expect(undefinedL()).toBeUndefined();
    expect(voidL()).toBeUndefined();
    expect(zeroL()).toBe(0);
    expect(falseL()).toBe(false);
    expect(trueL()).toBe(true);
  });
  it('exists', () => {
    expect(exists({})).toBeTruthy();
    expect(exists(null)).toBeFalsy();
    expect(exists(undefined)).toBeFalsy();
  });
  it('compact', () => {
    expect(compact([])).toEqual([]);
    expect(compact([false, null, '', undefined])).toEqual([]);
    expect(compact([{}, null])).toEqual([{}]);
  });
  it('some', () => {
    expect(some([])).toBeFalsy();
    expect(some([0, false, null, undefined, ''])).toBeFalsy();
    expect(some([1])).toBeTruthy();
    expect(some([0, 1])).toBeTruthy();
    expect(some([null, {}, null])).toBeTruthy();
  });
  it('parseIntSafe', () => {
    expect(parseIntSafe('0')).toBe(0);
    expect(parseIntSafe('0.1')).toBe(0);
    expect(parseIntSafe('1')).toBe(1);
    expect(parseIntSafe('2')).toBe(2);
    expect(parseIntSafe('')).toBe(0);
    expect(parseIntSafe('', 0)).toBe(0);
    expect(parseIntSafe('', 1)).toBe(1);
  });
  it('parseFloatSafe', () => {
    expect(parseFloatSafe('0')).toBe(0);
    expect(parseFloatSafe('0.1')).toBe(0.1);
    expect(parseFloatSafe('1.1')).toBe(1.1);
    expect(parseFloatSafe('2.1')).toBe(2.1);
    expect(parseFloatSafe('')).toBe(0);
    expect(parseFloatSafe('', 0)).toBe(0);
    expect(parseFloatSafe('', 1)).toBe(1);
  });
  it('isError', () => {
    expect(isError(null)).toBeFalsy();
    expect(isError(new Error())).toBeTruthy();
  });
  it('upFirst', () => {
    expect(upFirst('abc')).toBe('Abc');
  });
  it('getReadableBytes', () => {
    expect(getReadableBytes(1)).toBe('0.1 KiB');
    expect(getReadableBytes(99)).toBe('0.1 KiB');
    expect(getReadableBytes(1000)).toBe('1.0 KiB');
    expect(getReadableBytes(1001)).toBe('1.0 KiB');
    expect(getReadableBytes(9999)).toBe('9.8 KiB');
    expect(getReadableBytes(1000_000)).toBe('976.6 KiB');
    expect(getReadableBytes(1024_000)).toBe('1000.0 KiB');
    expect(getReadableBytes(1000_000_000)).toBe('953.7 MiB');
    expect(getReadableBytes(1000_000_000_000)).toBe('931.3 GiB');
  });
  it('delay', async () => {
    await expect(delay(1)).resolves.toBeUndefined();
  });
});
