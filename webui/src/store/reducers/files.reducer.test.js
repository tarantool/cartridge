import reducer from "./files.reducer";
import {
  createFile,
  createFolder,
  renameFile,
  renameFolder,
  deleteFile,
  deleteFolder,
} from "src/store/actions/files.actions";


describe('Deleting files', () => {
  const state = [
    { path: 'file.ext' },
    { path: 'folder/file.ext' },
    { path: 'folder/file2.ext' },
    { path: 'folder2/file.ext' },
  ];

  it('deletes one file', () => {
    expect(
      reducer(state, deleteFile({ id: 'folder/file.ext' }))
    ).toEqual([
      { path: 'file.ext' },
      { path: 'folder/file2.ext' },
      { path: 'folder2/file.ext' },
    ]);
  });

  it('deletes folder', () => {
    expect(
      reducer(state, deleteFolder({ id: 'folder' }))
    ).toEqual([
      { path: 'file.ext' },
      { path: 'folder2/file.ext' },
    ]);
  });

  // it('handles empty state', () => {
  //   expect(v2_selectFileTree([])).toEqual([]);
  // });
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
    { path: 'file.ext' },
    { path: 'folder/file.ext' },
    { path: 'folder/folder/file.ext' },
  ];

  it('renames folder in root', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'folder', name: 'renamedFolder' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'renamedFolder/file.ext' },
      { path: 'renamedFolder/folder/file.ext' },
    ]);
  });

  it('renames subfolder in folder', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'folder/folder', name: 'renamedFolder' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'folder/file.ext' },
      { path: 'folder/renamedFolder/file.ext' },
    ]);
  });

  it('returns previous state when folder not found', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'folder/nonExistingFolder', name: 'renamedFolder' }))
    ).toEqual(initialState);
  });
});

describe('Creating', () => {
  it('creates the first file in root', () => {
    const emptyState = [];

    expect(
      reducer(emptyState, createFile({ name: 'file.ext' }))
    ).toEqual([
      {
        path: 'file.ext', fileName: 'file.ext',
        type: 'file',
        content: '', initialContent: '',
        loading: false, saved: false,
        line: 0, column: 0, scrollPosition: 0,
      },
    ]);
  });

  it('creates a file in a folder', () => {
    const initialState = [
      { path: 'folder/folder/file.ext' },
    ];

    expect(
      reducer(initialState, createFile({ parentId: 'folder/folder', name: 'newFile.ext' }))
    ).toEqual([
      { path: 'folder/folder/file.ext' },
      {
        path: 'folder/folder/newFile.ext', fileName: 'newFile.ext',
        type: 'file',
        content: '', initialContent: '',
        loading: false, saved: false,
        line: 0, column: 0, scrollPosition: 0,
      }
    ]);
  });

  it('when creating a new file, keeps other files\' properties', () => {
    const presentFile = {
      path: 'folder/file.ext', fileName: 'file.ext',
      type: 'file',
      content: 'Some changed content', initialContent: 'Some initial content',
      loading: false, saved: false,
      line: 10, column: 20, scrollPosition: 30,
    };
    const initialState = [presentFile];

    expect(
      reducer(initialState, createFile({ parentId: '', name: 'newFile.ext' }))
    ).toEqual([
      presentFile,
      {
        path: 'newFile.ext', fileName: 'newFile.ext',
        type: 'file',
        content: '', initialContent: '',
        loading: false, saved: false,
        line: 0, column: 0, scrollPosition: 0,
      }
    ]);
  });
});
