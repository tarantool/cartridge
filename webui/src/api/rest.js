import axios from 'axios';
import _ from 'lodash';

export default {
  post(...args) {
    return axios.post(...args);
  },
  put(...args) {
    return axios.put(...args);
  },
  get(...args) {
    return axios.get(...args);
  },
  soap(object) {
    return axios.post(process.env.REACT_APP_SOAP_API_ENDPOINT, object, {
      headers: { 'Content-Type': 'application/json;charset=UTF-8' },
    });
  },
};

export const isRestErrorResponse
  = error =>
    error instanceof XMLHttpRequest;

export const getRestErrorMessage
  = error =>
    error.responseText || 'XMLHttpRequest error with empty message';

export const isRestAccessDeniedError
  = error =>
    isRestErrorResponse(error) && error.status === 401;

export const isAxiosError
  = error =>
  !!(_.get(error, 'config.adapter', false));

export const getAxiosErrorMessage
  = error =>
  (_.get(error, 'response.data.class_name', false) && _.get(error, 'response.data.err', false))
    ? `${_.get(error, 'response.data.class_name')}: ${_.get(error, 'response.data.err')}`
    : error.message;
