// @flow

const allowedFileExtensionsRegEx = /\.((lua)|(yml))$/;

export const validateFileNameExtension = (filename: string) => {
  return allowedFileExtensionsRegEx.test(filename);
};

/**
 *
 * @param {string} ownPath - own path of a examined file or folder
 * @param {string} parentPath - a folder's path (NO trailing slash "/"!)
 * @returns {boolean}
 */
export const isDescendant = (ownPath: string, parentPath: string): boolean => {
  return ownPath.substring(0, parentPath.length + 1) === `${parentPath}/`;
};
