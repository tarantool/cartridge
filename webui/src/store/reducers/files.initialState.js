export default [
  {
    fileId: '1',
    path: 'config.yml',
    fileName: 'config.yml',
    content: `--- []
...
`,
    initialContent: `--- []
...
`,
    loading: false,
    saved: true,
    type: 'file',
    column: 0,
    line: 0,
    scrollPosition: 0
  },
  {
    fileId: '5',
    path: 'test.js',
    fileName: 'test.js',
    content: `
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

`,
    initialContent: `
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

`,
    loading: false,
    saved: true,
    type: 'file',
    column: 0,
    line: 0,
    scrollPosition: 0
  },
  {
    fileId: '2',
    path: 'app.lua',
    fileName: 'app.lua',
    content: ``,
    initialContent: ``,
    loading: false,
    saved: true,
    type: 'file',
    column: 0,
    line: 0,
    scrollPosition: 0
  },
  {
    fileId: '3',
    path: 'lib',
    fileName: 'lib',
    content: ``,
    initialContent: ``,
    loading: false,
    saved: true,
    type: 'folder',
    column: 0,
    line: 0,
    scrollPosition: 0
  },
  {
    parentId: '3',
    fileId: '4',
    path: 'lib/utils.lua',
    fileName: 'utils.lua',
    content: ``,
    initialContent: ``,
    loading: false,
    saved: true,
    type: 'file',
    column: 0,
    line: 0,
    scrollPosition: 0
  },
  {
    'fileId': '7',
    'path': 'Folder',
    'fileName': 'Folder',
    'content': '',
    'initialContent': '',
    'loading': false,
    'saved': true,
    'type': 'folder',
    'column': 0,
    'line': 0,
    'scrollPosition': 0
  }
]
