import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';

const storageMap = new Map()

const getExtension = fileName => {
  const f = fileName.split('.')
  if (f.length > 1) {
    return f[f.length - 1]
  }
  return null
}

const extMap = {
  'lua': 'lua',
  'yml': 'yaml',
  'json': 'json',
  'js': 'javascript'
};

export const getLanguageByFileName = fileName => {
  const ext = getExtension(fileName)
  if (ext) {
    return extMap[ext]
  }
  return null
}

export const setModelByFile = (fileId: string, language: string, content: string) => {
  const model = monaco.editor.createModel(content, language, fileId)
  storageMap.set(fileId, model)
  return model
}

//TODO: do we really need this publicly? Can we pass simple fileId to <MonacoEditor>?
export const getFileIdForMonaco = fileId => `inmemory://${fileId}.lua`;

export const getModelByFile = fileId => storageMap.get(fileId)

export const getModelValueByFile = fileId => {
  const model = getModelByFile(fileId);
  if (model) {
    return model.getValue()
  }
  return null;
}

export const setModelValueByFile = (fileId, value) => {
  const model = getModelByFile(fileId);
  if (model) {
    model.pushEditOperations(
      [],
      [
        {
          range: model.getFullModelRange(),
          text: value
        }
      ]
    );
  }
}
