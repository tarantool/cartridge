import reducer from "./files.reducer";
import type { FileItem } from './files.reducer'
import {
  createFile,
  createFolder,
  renameFile,
  renameFolder,
  deleteFile,
  deleteFolder,
} from "src/store/actions/files.actions";

const checkFileId = (file: FileItem) => {
  if (file.type === 'file' && !file.fileId) {
    throw new Error('no file id for file')
  }
}

describe('Deleting files', () => {
  const state = [
    { path: 'file.ext' },
    { path: 'folder/file.ext' },
    { path: 'folder/file2.ext' },
    { path: 'folder/subfolder/file.ext' },
    { path: 'folder2/file.ext' },
  ];

  it('deletes one file', () => {
    expect(
      reducer(state, deleteFile({ id: 'folder/file.ext' }))
    ).toEqual([
      { path: 'file.ext' },
      { path: 'folder/file.ext', deleted: true },
      { path: 'folder/file2.ext' },
      { path: 'folder/subfolder/file.ext' },
      { path: 'folder2/file.ext' },
    ]);
  });

  it('deletes folder (all its files and subfolders)', () => {
    expect(
      reducer(state, deleteFolder({ id: 'folder' }))
    ).toEqual([
      { path: 'file.ext' },
      { path: 'folder/file.ext', deleted: true },
      { path: 'folder/file2.ext', deleted: true },
      { path: 'folder/subfolder/file.ext', deleted: true },
      { path: 'folder2/file.ext' },
    ]);
  });

});

describe('Renaming files', () => {
  it('renames file in root', () => {
    expect(
      reducer([
        { path: 'file.ext' },
        { path: 'folder/file.ext' },
      ], renameFile({ id: 'file.ext', name: 'renamed.txt' }))
    ).toMatchObject([
      { path: 'renamed.txt' },
      { path: 'folder/file.ext' },
    ]);
  });

  it('renames file in folder', () => {
    expect(
      reducer([
        { path: 'file.ext' },
        { path: 'folder/file.ext' },
      ], renameFile({ id: 'folder/file.ext', name: 'renamed.txt' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'folder/renamed.txt' },
    ]);
  });


  const initialState = [
    { path: 'file.ext', parentPath: '' },
    { path: 'dir', parentPath: '', type: 'folder' },
    { path: 'dir/file.ext', parentPath: 'dir' },
    { path: 'dir/dir', parentPath: 'dir', type: 'folder' },
    { path: 'dir/dir/file.ext', parentPath: 'dir/dir' },
  ];

  it('renames folder in root', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'dir', name: 'renamedDir' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'renamedDir', parentPath: '' },
      { path: 'renamedDir/file.ext', parentPath: 'renamedDir' },
      { path: 'renamedDir/dir', parentPath: 'renamedDir' },
      { path: 'renamedDir/dir/file.ext', parentPath: 'renamedDir/dir' },
    ]);
  });

  it('renames subfolder in folder', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'dir/dir', name: 'renamedDir' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'dir' },
      { path: 'dir/file.ext' },
      { path: 'dir/renamedDir' },
      { path: 'dir/renamedDir/file.ext' },
    ]);
  });

  it('returns previous state when folder not found', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'dir/nonExistingDir', name: 'renamedDir' }))
    ).toEqual(initialState);
  });
});

describe('Creating', () => {
  it('creates the first file in root', () => {
    const emptyState = [];
    const state = reducer(emptyState, createFile({ name: 'file.ext', parentPath: '' }))
    expect(
      state
    ).toMatchObject([
      {
        path: 'file.ext', fileName: 'file.ext',
        parentPath: '',
        type: 'file',
        initialContent: null,
        loading: false, saved: false,
        line: 0, column: 0, scrollPosition: 0,
      },
    ]);
    state.forEach(checkFileId)
  });

  it('creates a file in a folder', () => {
    const initialState = [
      { path: 'folder/folder/file.ext' },
    ];

    const parentPath = 'folder/folder';
    const state = reducer(initialState, createFile({ parentPath, name: 'newFile.ext' }))
    expect(
      state
    ).toMatchObject([
      { path: 'folder/folder/file.ext' },
      {
        path: 'folder/folder/newFile.ext', fileName: 'newFile.ext',
        parentPath: parentPath,
        type: 'file',
        initialContent: null,
        loading: false, saved: false,
        line: 0, column: 0, scrollPosition: 0,
      }
    ]);
    state.forEach(checkFileId)
  });

  it('when creating a new file, keeps other files\' properties', () => {
    const presentFile = {
      path: 'folder/file.ext', fileName: 'file.ext',
      type: 'file',
      initialContent: 'Some initial content',
      loading: false, saved: false,
      line: 10, column: 20, scrollPosition: 30,
    };
    const initialState = [presentFile];

    const parentPath = '';
    expect(
      reducer(initialState, createFile({ parentPath, name: 'newFile.ext' }))
    ).toEqual([
      presentFile,
      {
        fileId: '3',
        path: 'newFile.ext', fileName: 'newFile.ext',
        parentPath: parentPath,
        type: 'file',
        initialContent: null,
        loading: false, saved: false,
        line: 0, column: 0, scrollPosition: 0,
      }
    ]);
  });
});
