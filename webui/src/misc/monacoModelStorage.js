import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';

const storage = {}

const getExtension = fileName => {
  const f = fileName.split('.')
  if (f.length > 1) {
    return f[f.length-1]
  }
  return null
}

const extMap = {
  'lua': 'lua',
  'yml': 'yaml',
  'json': 'json',
  'js': 'js'
};

const getLanguageByFileName = fileName => {
  const ext = getExtension(fileName)
  if (ext) {
    return extMap[ext]
  }
  return null
}

export const setModelContent = (file, content) => {
  if (storage[file]) {
    storage[file].setValue(content)
  }
  else {
    const model = monaco.editor.createModel(content, getLanguageByFileName(file))
    storage[file] = model
  }
}

export const dropModels = () => {
  for (const file in storage) {
    if (storage[file]) {
      storage[file].dispose()
    }
  }
}
