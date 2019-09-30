import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';

const storage = {}

const storageMap = new Map()

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
  'js': 'javascript'
};

export const getLanguageByFileName = fileName => {
  const ext = getExtension(fileName)
  if (ext) {
    return extMap[ext]
  }
  return null
}

export const setModelContent = (file, content) => {
  if (storage[file]) {
    storage[file].setValue(content)
  } else {
    const model = monaco.editor.createModel(content, getLanguageByFileName(file), file)
    storage[file] = model
  }
}
//
// export const setModelPosition = (file, position) => {
//   if (storage[file]) {
//     storage[file].setValue(content)
//   } else {
//     const model = monaco.editor.createModel(content, getLanguageByFileName(file), file)
//     storage[file] = model
//   }
// }

export const setModelByFile = (file, language, content) => {
  const model = monaco.editor.createModel(content, language, file)
  storageMap.set(file, model)
  return model
}

export const getModelByFile = file => storageMap.get(file)

export const dropModels = () => {
  for (const file in storage) {
    if (storage[file]) {
      storage[file].dispose()
    }
  }
}
