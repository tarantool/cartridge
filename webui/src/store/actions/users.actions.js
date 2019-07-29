import {
  SET_ADD_USER_MODAL_VISIBLE,
  SET_EDIT_USER_MODAL_VISIBLE,
  SET_REMOVE_USER_MODAL_VISIBLE,
  USER_LIST_REQUEST,
  USER_ERROR_RESET,
  USER_STATE_RESET,
  USER_ADD_REQUEST,
  USER_REMOVE_REQUEST,
  USER_EDIT_REQUEST
} from 'src/store/actionTypes';

export const resetUserErrors = () => ({ type: USER_ERROR_RESET });

export const resetUserState = () => ({ type: USER_STATE_RESET });

export const showAddUserModal = () => ({
  type: SET_ADD_USER_MODAL_VISIBLE,
  payload: { visible: true }
});

export const hideAddUserModal = () => ({
  type: SET_ADD_USER_MODAL_VISIBLE,
  payload: { visible: false }
});

export const showEditUserModal = username => ({
  type: SET_EDIT_USER_MODAL_VISIBLE,
  payload: { username, visible: true }
});

export const hideEditUserModal = () => ({
  type: SET_EDIT_USER_MODAL_VISIBLE,
  payload: { visible: false }
});

export const showRemoveUserModal = username => ({
  type: SET_REMOVE_USER_MODAL_VISIBLE,
  payload: { username, visible: true }
});

export const hideRemoveUserModal = () => ({
  type: SET_REMOVE_USER_MODAL_VISIBLE,
  payload: { visible: false }
});

export const getUsersList = () => ({ type: USER_LIST_REQUEST });

export const addUser = ({
  email,
  fullname,
  password,
  username
}) => ({
  type: USER_ADD_REQUEST,
  payload: {
    email,
    fullname,
    password,
    username
  }
});

export const editUser = ({
  email,
  fullname,
  password,
  username
}) => ({
  type: USER_EDIT_REQUEST,
  payload: {
    email,
    fullname,
    password,
    username
  }
});

export const removeUser = username => ({
  type: USER_REMOVE_REQUEST,
  payload: { username }
});
