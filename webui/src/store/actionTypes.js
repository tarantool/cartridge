// @flow

// const types = (type: string) => ({
//   try: `${type}_try`,
//   done: `${type}_done`,
//   fail: `${type}_fail`,
// })

/* APP */
export const APP_DID_MOUNT = 'APP_DID_MOUNT';

export const APP_DATA_REQUEST = 'APP_DATA_REQUEST';
export const APP_DATA_REQUEST_SUCCESS = 'APP_DATA_REQUEST_SUCCESS';
export const APP_DATA_REQUEST_ERROR = 'APP_DATA_REQUEST_ERROR';

export const APP_CREATE_MESSAGE = 'APP_CREATE_MESSAGE';
export const APP_SET_MESSAGE_DONE = 'APP_SET_MESSAGE_DONE';

export const APP_CONNECTION_STATE_CHANGE = 'APP_CONNECTION_STATE_CHANGE';

/* CLUSTER_PAGE */
export const CLUSTER_PAGE_DID_MOUNT = 'CLUSTER_PAGE_DID_MOUNT';

export const CLUSTER_PAGE_FILTER_SET = 'CLUSTER_PAGE_FILTER_SET';
export const CLUSTER_PAGE_MODAL_FILTER_SET = 'CLUSTER_PAGE_MODAL_FILTER_SET';

export const CLUSTER_PAGE_DATA_REQUEST = 'CLUSTER_PAGE_DATA_REQUEST';
export const CLUSTER_PAGE_DATA_REQUEST_SUCCESS = 'CLUSTER_PAGE_DATA_REQUEST_SUCCESS';
export const CLUSTER_PAGE_DATA_REQUEST_ERROR = 'CLUSTER_PAGE_DATA_REQUEST_ERROR';

export const CLUSTER_PAGE_REFRESH_LISTS_REQUEST = 'CLUSTER_PAGE_REFRESH_LISTS_REQUEST';
export const CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS = 'CLUSTER_PAGE_REFRESH_LISTS_REQUEST_SUCCESS';
export const CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR = 'CLUSTER_PAGE_REFRESH_LISTS_REQUEST_ERROR';

export const CLUSTER_PAGE_SERVER_LIST_ROW_SELECT = 'CLUSTER_PAGE_SERVER_LIST_ROW_SELECT';
export const CLUSTER_PAGE_SERVER_POPUP_CLOSE = 'CLUSTER_PAGE_SERVER_POPUP_CLOSE';

export const CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT = 'CLUSTER_PAGE_REPLICASET_LIST_ROW_SELECT';
export const CLUSTER_PAGE_REPLICASET_POPUP_CLOSE = 'CLUSTER_PAGE_REPLICASET_POPUP_CLOSE';

export const CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST = 'CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST';
export const CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS = 'CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_SUCCESS';
export const CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR = 'CLUSTER_PAGE_BOOTSTRAP_VSHARD_REQUEST_ERROR';

export const CLUSTER_PAGE_PROBE_SERVER_REQUEST = 'CLUSTER_PAGE_PROBE_SERVER_REQUEST';
export const CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS = 'CLUSTER_PAGE_PROBE_SERVER_REQUEST_SUCCESS';
export const CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR = 'CLUSTER_PAGE_PROBE_SERVER_REQUEST_ERROR';

export const CLUSTER_PAGE_JOIN_SERVER_REQUEST = 'CLUSTER_PAGE_JOIN_SERVER_REQUEST';
export const CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS = 'CLUSTER_PAGE_JOIN_SERVER_REQUEST_SUCCESS';
export const CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR = 'CLUSTER_PAGE_JOIN_SERVER_REQUEST_ERROR';

export const CLUSTER_PAGE_CREATE_REPLICASET_REQUEST = 'CLUSTER_PAGE_CREATE_REPLICASET_REQUEST';
export const CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS = 'CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_SUCCESS';
export const CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR = 'CLUSTER_PAGE_CREATE_REPLICASET_REQUEST_ERROR';

export const SHOW_EXPEL_MODAL: 'SHOW_EXPEL_MODAL' = 'SHOW_EXPEL_MODAL'
export const HIDE_EXPEL_MODAL: 'HIDE_EXPEL_MODAL' = 'HIDE_EXPEL_MODAL'

export const CLUSTER_PAGE_EXPEL_SERVER_REQUEST = 'CLUSTER_PAGE_EXPEL_SERVER_REQUEST';
export const CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS = 'CLUSTER_PAGE_EXPEL_SERVER_REQUEST_SUCCESS';
export const CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR = 'CLUSTER_PAGE_EXPEL_SERVER_REQUEST_ERROR';

export const CLUSTER_PAGE_REPLICASET_EDIT_REQUEST = 'CLUSTER_PAGE_REPLICASET_EDIT_REQUEST';
export const CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS = 'CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_SUCCESS';
export const CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR = 'CLUSTER_PAGE_REPLICASET_EDIT_REQUEST_ERROR';

export const CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST = 'CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST';
export const CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS = 'CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_SUCCESS';
export const CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR = 'CLUSTER_PAGE_UPLOAD_CONFIG_REQUEST_ERROR';

export const CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST = 'CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST';
export const CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_SUCCESS = 'CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_SUCCESS';
export const CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_ERROR = 'CLUSTER_PAGE_APPLY_TEST_CONFIG_REQUEST_ERROR';

export const CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST = 'CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST';
export const CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS = 'CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_SUCCESS';
export const CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR = 'CLUSTER_PAGE_FAILOVER_CHANGE_REQUEST_ERROR';

export const CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST = 'CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST';
export const CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_SUCCESS = 'CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_SUCCESS';
export const CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_ERROR = 'CLUSTER_PAGE_FAILOVER_PROMOTE_REQUEST_ERROR';

export const CLUSTER_SELF_UPDATE = 'CLUSTER_SELF_UPDATE';

export const CLUSTER_PAGE_STATE_RESET = 'CLUSTER_PAGE_STATE_RESET';

export const CLUSTER_PAGE_ZONE_UPDATE = 'CLUSTER_PAGE_ZONE_UPDATE';

export const SET_BOOSTRAP_VSHARD_PANEL_VISIBLE = 'SET_BOOSTRAP_VSHARD_PANEL_VISIBLE';
export const SET_FAILOVER_MODAL_VISIBLE = 'SET_FAILOVER_MODAL_VISIBLE';
export const SET_PROBE_SERVER_MODAL_VISIBLE = 'SET_PROBE_SERVER_MODAL_VISIBLE';

/* CLUSTER */
export const CLUSTER_DISABLE_INSTANCE_REQUEST = 'CLUSTER_DISABLE_INSTANCE_REQUEST';
export const CLUSTER_DISABLE_INSTANCE_REQUEST_SUCCESS = 'CLUSTER_DISABLE_INSTANCE_REQUEST_SUCCESS';
export const CLUSTER_DISABLE_INSTANCE_REQUEST_ERROR = 'CLUSTER_DISABLE_INSTANCE_REQUEST_ERROR';

/* CLUSTER_INSTANCE_PAGE */
export const CLUSTER_INSTANCE_DID_MOUNT = 'CLUSTER_INSTANCE_DID_MOUNT';

export const CLUSTER_INSTANCE_DATA_REQUEST = 'CLUSTER_INSTANCE_DATA_REQUEST';
export const CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS = 'CLUSTER_INSTANCE_DATA_REQUEST_SUCCESS';
export const CLUSTER_INSTANCE_DATA_REQUEST_ERROR = 'CLUSTER_INSTANCE_DATA_REQUEST_ERROR';

export const CLUSTER_INSTANCE_REFRESH_REQUEST = 'CLUSTER_INSTANCE_REFRESH_REQUEST';
export const CLUSTER_INSTANCE_REFRESH_REQUEST_SUCCESS = 'CLUSTER_INSTANCE_REFRESH_REQUEST_SUCCESS';
export const CLUSTER_INSTANCE_REFRESH_REQUEST_ERROR = 'CLUSTER_INSTANCE_REFRESH_REQUEST_ERROR';

export const CLUSTER_INSTANCE_STATE_RESET = 'CLUSTER_INSTANCE_STATE_RESET';

/* Authorization */
export const AUTH_ACCESS_DENIED = 'AUTH_ACCESS_DENIED';

export const AUTH_TURN_REQUEST = 'AUTH_TURN_REQUEST';
export const AUTH_TURN_REQUEST_SUCCESS = 'AUTH_TURN_REQUEST_SUCCESS';
export const AUTH_TURN_REQUEST_ERROR = 'AUTH_TURN_REQUEST_ERROR';

export const AUTH_LOG_IN_REQUEST = 'AUTH_LOG_IN_REQUEST';
export const AUTH_LOG_IN_REQUEST_SUCCESS = 'AUTH_LOG_IN_REQUEST_SUCCESS';
export const AUTH_LOG_IN_REQUEST_ERROR = 'AUTH_LOG_IN_REQUEST_ERROR';

export const AUTH_LOG_OUT_REQUEST = 'AUTH_LOG_OUT_REQUEST';
export const AUTH_LOG_OUT_REQUEST_SUCCESS = 'AUTH_LOG_OUT_REQUEST_SUCCESS';
export const AUTH_LOG_OUT_REQUEST_ERROR = 'AUTH_LOG_OUT_REQUEST_ERROR';

/* Users */
export const SET_AUTH_MODAL_VISIBLE = 'SET_AUTH_MODAL_VISIBLE';
export const EXPECT_WELCOME_MESSAGE = 'EXPECT_WELCOME_MESSAGE';
export const SET_WELCOME_MESSAGE = 'SET_WELCOME_MESSAGE';

/* Config files */

export const FETCH_CONFIG_FILES = 'FETCH_CONFIG_FILES'
export const FETCH_CONFIG_FILES_DONE = 'FETCH_CONFIG_FILES_DONE'
export const FETCH_CONFIG_FILES_FAIL = 'FETCH_CONFIG_FILES_FAIL'

export const FETCH_CONFIG_FILE_CONTENT = 'FETCH_CONFIG_FILE_CONTENT'
export const FETCH_CONFIG_FILE_CONTENT_DONE = 'FETCH_CONFIG_FILE_CONTENT_DONE'
export const FETCH_CONFIG_FILE_CONTENT_FAIL = 'FETCH_CONFIG_FILE_CONTENT_FAIL'

export const PUT_CONFIG_FILES_CONTENT = 'PUT_CONFIG_FILES_CONTENT'
export const PUT_CONFIG_FILES_CONTENT_DONE = 'PUT_CONFIG_FILES_CONTENT_DONE'
export const PUT_CONFIG_FILES_CONTENT_FAIL = 'PUT_CONFIG_FILES_CONTENT_FAIL'

export const SELECT_FILE = 'SELECT_FILE'
export const UPDATE_CONTENT = 'UPDATE_CONTENT'
export const SAVE_META_FILE = 'SAVE_META_FILE'

export const SET_IS_CONTENT_CHANGED = 'SET_IS_CONTENT_CHANGED'

export const CREATE_FILE = 'CREATE_FILE'
export const CREATE_FOLDER = 'CREATE_FOLDER'
export const DELETE_FILE = 'DELETE_FILE'
export const DELETE_FOLDER = 'DELETE_FOLDER'
export const RENAME_FILE = 'RENAME_FILE'
export const RENAME_FOLDER = 'RENAME_FOLDER'

// export const createFile = types(CREATE_FILE)
// export const createFolder = types(CREATE_FOLDER)
// export const deleteFile = types(DELETE_FILE)
// export const deleteFolder = types(DELETE_FOLDER)
// export const renameFile = types(RENAME_FILE)
// export const renameFolder = types(RENAME_FOLDER)
