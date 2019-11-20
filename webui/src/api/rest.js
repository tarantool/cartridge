import axios from 'axios';
import _ from 'lodash';

const axiosInstance = axios.create()

window.tarantool_enterprise_core.apiMethods.axiosWizard(axiosInstance)

export default {
  post(...args) {
    return axiosInstance.post(...args);
  },
  put(...args) {
    return axiosInstance.put(...args);
  },
  get(...args) {
    return axiosInstance.get(...args);
  },
  soap(object) {
    return axiosInstance.post(process.env.REACT_APP_SOAP_API_ENDPOINT, object, {
      headers: { 'Content-Type': 'application/json;charset=UTF-8' }
    });
  }
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
