import {
  v2_selectFileTree,
} from './filesSelectors';

describe('selectFileTree (v2)', () => {
  it('correctly forms tree (files at root, folder, subfolders)', () => {
    const state = [
      { path: 'rootFile.ext',           parentPath: '',             type: 'file' },
      { path: 'rootFile2.ext',          parentPath: '',             type: 'file' },
      { path: 'rootFolder',             parentPath: '',             type: 'folder' },
      { path: 'rootFolder/file.ext',    parentPath: 'rootFolder',   type: 'file' },
      { path: 'rootFolder2',            parentPath: '',             type: 'folder' },
      { path: 'rootFolder2/file1.ext',  parentPath: 'rootFolder2',  type: 'file' },
      { path: 'rootFolder2/file2.ext',  parentPath: 'rootFolder2',  type: 'file' },
      { path: 'rootFolder2/subFolder',  parentPath: 'rootFolder2',  type: 'folder' },
      { path: 'rootFolder2/subFolder/file.ext', parentPath: 'rootFolder2', type: 'file' },
      { path: 'rootFolder2/subFolder2', parentPath: 'rootFolder2',  type: 'folder' },
      { path: 'rootFolder2/subFolder2/file.ext', parentPath: 'rootFolder2/subFolder2', type: 'file' },
    ];

    expect(v2_selectFileTree(state)).toMatchObject([
      {
        fileId: 'rootFolder', path: 'rootFolder',
        fileName: 'rootFolder', type: 'folder',
        items: [
          {
            fileId: 'rootFolder/file.ext', path: 'rootFolder/file.ext',
            fileName: 'file.ext', type: 'file',
          },
        ]
      },
      {
        fileId: 'rootFolder2', path: 'rootFolder2',
        fileName: 'rootFolder2', type: 'folder',
        items: [
          {
            fileId: 'rootFolder2/subFolder', path: 'rootFolder2/subFolder',
            fileName: 'subFolder', type: 'folder',
            items: [
              {
                fileId: 'rootFolder2/subFolder/file.ext', path: 'rootFolder2/subFolder/file.ext',
                fileName: 'file.ext', type: 'file',
              },
            ]
          },
          {
            fileId: 'rootFolder2/subFolder2', path: 'rootFolder2/subFolder2',
            fileName: 'subFolder2', type: 'folder',
            items: [
              {
                fileId: 'rootFolder2/subFolder2/file.ext', path: 'rootFolder2/subFolder2/file.ext',
                fileName: 'file.ext', type: 'file',
              },
            ]
          },
          {
            fileId: 'rootFolder2/file1.ext', path: 'rootFolder2/file1.ext',
            fileName: 'file1.ext', type: 'file',
          },
          {
            fileId: 'rootFolder2/file2.ext', path: 'rootFolder2/file2.ext',
            fileName: 'file2.ext', type: 'file',
          },
        ]
      },
      {
        fileId: 'rootFile.ext', path: 'rootFile.ext',
        fileName: 'rootFile.ext', type: 'file',
      },
      {
        fileId: 'rootFile2.ext', path: 'rootFile2.ext',
        fileName: 'rootFile2.ext', type: 'file',
      },
    ]);
  });


  it('duplicate files are not repeated', () => {
    const stateWithDuplicateFiles = [
      { path: 'duplicate/files.ext' },
      { path: 'duplicate/files.ext' },
    ];

    expect(v2_selectFileTree(stateWithDuplicateFiles)).toMatchObject([
      {
        fileId: 'duplicate', path: 'duplicate',
        fileName: 'duplicate', type: 'folder',
        items: [
          {
            fileId: 'duplicate/files.ext', path: 'duplicate/files.ext',
            fileName: 'files.ext', type: 'file',
          }
        ]
      },
    ]);
  });

  it('keeps files\' properties', () => {
    const state = [
      { path: 'rootFile.ext' },
      {
        path: 'folder/file.ext', fileName: 'file.ext',
        type: 'file',
        content: 'Some changed content', initialContent: 'Some initial content',
        loading: false, saved: false,
        line: 10, column: 20, scrollPosition: 30,
      },
      { path: 'folder/file2.ext' },
    ];

    expect(v2_selectFileTree(state)).toMatchObject([
      {
        fileId: 'rootFile.ext', path: 'rootFile.ext',
        fileName: 'rootFile.ext', type: 'file',
      },
      {
        fileId: 'folder', path: 'folder',
        fileName: 'folder', type: 'folder',
        items: [
          state[1],
          {
            fileId: 'folder/file2.ext', path: 'folder/file2.ext',
            fileName: 'file2.ext', type: 'file',
          }
        ]
      },
    ]);
  });


  it('handles empty state', () => {
    expect(v2_selectFileTree([])).toEqual([]);
  });
});
