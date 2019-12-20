import {
  selectFileTree,
} from './filesSelectors';

describe('selectFileTree', () => {
  it('correctly forms tree (files at root, folder, subfolders)', () => {
    const state = [{
      'path': 'rootFile.ext',
      'parentPath': '',
      'type': 'file',
      'fileId': 'rootFile.ext',
      'fileName': 'rootFile.ext'
    }, {
      'path': 'rootFile2.ext',
      'parentPath': '',
      'type': 'file',
      'fileId': 'rootFile2.ext',
      'fileName': 'rootFile2.ext'
    }, {
      'path': 'rootFolder',
      'parentPath': '',
      'type': 'folder',
      'fileId': 'rootFolder',
      'fileName': 'rootFolder'
    }, {
      'path': 'rootFolder/file.ext',
      'parentPath': 'rootFolder',
      'type': 'file',
      'fileId': 'rootFolder/file.ext',
      'fileName': 'rootFolder/file.ext'
    }, {
      'path': 'rootFolder2',
      'parentPath': '',
      'type': 'folder',
      'fileId': 'rootFolder2',
      'fileName': 'rootFolder2'
    }, {
      'path': 'rootFolder2/file1.ext',
      'parentPath': 'rootFolder2',
      'type': 'file',
      'fileId': 'rootFolder2/file1.ext',
      'fileName': 'rootFolder2/file1.ext'
    }, {
      'path': 'rootFolder2/file2.ext',
      'parentPath': 'rootFolder2',
      'type': 'file',
      'fileId': 'rootFolder2/file2.ext',
      'fileName': 'rootFolder2/file2.ext'
    }, {
      'path': 'rootFolder2/subFolder',
      'parentPath': 'rootFolder2',
      'type': 'folder',
      'fileId': 'rootFolder2/subFolder',
      'fileName': 'rootFolder2/subFolder'
    }, {
      'path': 'rootFolder2/subFolder/file.ext',
      'parentPath': 'rootFolder2',
      'type': 'file',
      'fileId': 'rootFolder2/subFolder/file.ext',
      'fileName': 'rootFolder2/subFolder/file.ext'
    }, {
      'path': 'rootFolder2/subFolder2',
      'parentPath': 'rootFolder2',
      'type': 'folder',
      'fileId': 'rootFolder2/subFolder2',
      'fileName': 'rootFolder2/subFolder2'
    }, {
      'path': 'rootFolder2/subFolder2/file.ext',
      'parentPath': 'rootFolder2/subFolder2',
      'type': 'file',
      'fileId': 'rootFolder2/subFolder2/file.ext',
      'fileName': 'rootFolder2/subFolder2/file.ext'
    }];

    expect(selectFileTree(state)).toMatchObject([
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
      { type: 'folder', path: 'duplicate', parentPath: '', deleted: false},
      { type: 'file', path: 'duplicate/files.ext', deleted: false, parentPath: 'duplicate' },
      { type: 'file', path: 'duplicate/files.ext', deleted: false, parentPath: 'duplicate' },
    ];

    expect(selectFileTree(stateWithDuplicateFiles)).toMatchObject([
      {
        path: 'duplicate',
        type: 'folder',
        items: [
          {
            path: 'duplicate/files.ext',
            type: 'file',
          }
        ]
      },
    ]);
  });

  it('keeps files\' properties', () => {
    const state = [
      {
        path: 'rootFile.ext',
        initialPath: 'rootFile.ext',
        type: 'file',
        deleted: false,
        saved: true,
        parentPath: '',
      },
      {
        path: 'folder/file.ext',
        parentPath: 'folder',
        fileName: 'file.ext',
        type: 'file',
        content: 'Some changed content',
        initialContent: 'Some initial content',
        loading: false,
        saved: false,
        deleted: false,
        line: 10, column: 20, scrollPosition: 30,
      },
      { path: 'folder/file2.ext', parentPath: 'folder', deleted: false, type: 'file' },
      {
        path: 'folder',
        type: 'folder'
      },
    ];

    expect(selectFileTree(state)).toMatchObject([
      {
        path: 'folder',
        type: 'folder',
        items: [
          {...state[1], items: []},
          {
            parentPath: 'folder',
            path: 'folder/file2.ext',
            deleted: false,
            type: 'file',
            items: [],
          }
        ]
      },
      {
        path: 'rootFile.ext',
        type: 'file',
        items: [],
      },
    ]);
  });


  it('handles empty state', () => {
    expect(selectFileTree([])).toEqual([]);
  });
});
