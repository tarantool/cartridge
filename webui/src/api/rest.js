import axios from 'axios';

import { getApiEndpoint } from 'src/apiEndpoints';

import {
  getAxiosErrorMessage,
  getRestErrorMessage,
  isAxiosError,
  isRestAccessDeniedError,
  isRestErrorResponse,
} from './utils';

export { isRestErrorResponse, getAxiosErrorMessage, isAxiosError, isRestAccessDeniedError, getRestErrorMessage };

const axiosInstance = axios.create();

window.tarantool_enterprise_core.apiMethods.axiosWizard(axiosInstance);

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
    return axiosInstance.post(getApiEndpoint('SOAP_API_ENDPOINT'), object, {
      headers: { 'Content-Type': 'application/json;charset=UTF-8' },
    });
  },
};
