
const allowedFileExtentionsRegEx = /\.((lua)|(yml))$/;

export const validateFileNameExtention = (filename: string) => {
  return allowedFileExtentionsRegEx.test(filename);
}
