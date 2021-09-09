import yaml from 'js-yaml';
import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';

const convertYAMLExceptionToMonacoMarker = (exception) => {
  const { mark, message } = exception;
  if (!mark) {
    return null;
  }

  return {
    endColumn: mark.column + 1,
    endLineNumber: mark.line + 1,
    message,
    startColumn: mark.column + 1,
    startLineNumber: mark.line + 1,
    severity: monaco.MarkerSeverity.Error,
  };
};

export const getYAMLError = (data) => {
  try {
    yaml.safeLoad(data);
    return null;
  } catch (error) {
    return convertYAMLExceptionToMonacoMarker(error);
  }
};
