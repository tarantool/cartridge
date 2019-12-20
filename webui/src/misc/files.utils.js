
const allowedFileExtentionsRegEx = /\.((lua)|(yml))$/;

export const validateFileNameExtension = (filename: string) => {
  return allowedFileExtentionsRegEx.test(filename);
}
