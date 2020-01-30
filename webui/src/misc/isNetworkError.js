// @flow
export const isNetworkError = (err: any): boolean => {
  return err instanceof Error && err.message.toLowerCase().indexOf('network error') === 0;
};
