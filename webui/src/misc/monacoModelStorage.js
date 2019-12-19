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

export const setModelByFile = (file, language, content) => {
  const model = monaco.editor.createModel(content, language, file)
  storageMap.set(file, model)
  return model
}

export const getModelByFile = file => storageMap.get(file)

