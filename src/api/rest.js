import axios from 'axios';

export default {
  post(...args) {
    return axios.post(...args);
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
