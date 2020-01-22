// @flow
import reducer, { type CodeEditorState } from './codeEditor.reducer';
import {
  deleteFile,
  deleteFolder,
} from 'src/store/actions/files.actions';

describe('When the selected file gets deleted', () => {
  const _fileBlank = {
    fileId: '',
    path: '',
    parentPath: '',
    fileName: '',
    initialContent: '',
    saved: false,
    type: 'file',
    column: 0,
    line: 0,
    scrollPosition: 0,
    deleted: false,
  };

  const state: CodeEditorState = {
    editor: {
      selectedFile: '1',
    },
    files: [
      { ..._fileBlank, fileId: '1', path: 'folder/file.txt' },
      { ..._fileBlank, fileId: '2', path: 'folder' },
    ],
  };


  it('if the selected file is deleted, reset the file selection', () => {
    expect(
      reducer(state, deleteFile({ id: 'folder/file.txt' }))
    ).toEqual({
      editor: {
        selectedFile: null,
      },
      files: [
        { ..._fileBlank, fileId: '1', path: 'folder/file.txt', deleted: true },
        { ..._fileBlank, fileId: '2', path: 'folder' },
      ],
    });
  });


  it('if a folder that contains selected file is deleted, reset the file selection', () => {
    expect(
      reducer(state, deleteFolder({ id: 'folder' }))
    ).toEqual({
      editor: {
        selectedFile: null,
      },
      files: [
        { ..._fileBlank, fileId: '1', path: 'folder/file.txt', deleted: true },
        { ..._fileBlank, fileId: '2', path: 'folder', deleted: true },
      ],
    });
  });

});
