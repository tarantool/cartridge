import { REFRESH_LIST_INTERVAL, STAT_REQUEST_PERIOD } from 'src/constants';

import { parseIntSafe } from './utils';

const wtv = () => window['__tarantool_variables'] || {};

export const cartridge_refresh_interval = (): number =>
  parseIntSafe(wtv().cartridge_refresh_interval, REFRESH_LIST_INTERVAL);

export const cartridge_stat_period = (): number => parseIntSafe(wtv().cartridge_stat_period, STAT_REQUEST_PERIOD);

export const cartridge_hide_all_rw = (): boolean => wtv().cartridge_hide_all_rw === true;
