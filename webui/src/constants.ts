export const PROJECT_NAME = 'cluster';

export const REFRESH_LIST_INTERVAL = 2500;

export const STAT_REQUEST_PERIOD = 3;

// const DEFAULT_VSHARD_GROUP_NAME = 'default'; // indicates vshard groups are disabled

export const LS_CODE_EDITOR_OPENED_FILE = 'tarantool_cartridge_editor_opened_file';
export const SS_CODE_EDITOR_CURSOR_POSITION = 'tarantool_cartridge_editor_cursor_position';

export const FAILOVER_STATE_PROVIDERS = [
  { value: 'tarantool', label: 'Tarantool (stateboard)' },
  { value: 'etcd2', label: 'Etcd' },
];

export const BUILT_IN_USERS = ['admin'];

export const AUTH_TRIGGER_SESSION_KEY = 'tt.auth.trigger';
