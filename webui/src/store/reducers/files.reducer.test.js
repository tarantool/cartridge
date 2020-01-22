import reducer from './files.reducer';
import type { FileItem } from './files.reducer'
import {
  createFile,
  createFolder,
  renameFile,
  renameFolder,
  deleteFile,
  deleteFolder
} from 'src/store/actions/files.actions';

const checkFileId = (file: FileItem) => {
  if (!file.fileId) {
    throw new Error(`No fileId in file:\n${JSON.stringify(file, null, 2)}`);
  }
}


describe('Deleting files', () => {
  const state = [
    { path: 'file.ext' },
    { path: 'folder/file.ext' },
    { path: 'folder/file2.ext' },
    { path: 'folder/subfolder/file.ext' },
    { path: 'folder2/file.ext' }
  ];

  it('deletes one file', () => {
    expect(
      reducer(state, deleteFile({ id: 'folder/file.ext' }))
    ).toEqual([
      { path: 'file.ext' },
      { path: 'folder/file.ext', deleted: true },
      { path: 'folder/file2.ext' },
      { path: 'folder/subfolder/file.ext' },
      { path: 'folder2/file.ext' }
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
      { path: 'folder2/file.ext' }
    ]);
  });

});


describe('Renaming', () => {
  describe('Renaming files', () => {
    const initialState = [
      { path: 'file.ext' },
      { path: 'folder/file.ext' }
    ];

    it('renames file in root', () => {
      expect(
        reducer(initialState, renameFile({ id: 'file.ext', name: 'renamed.txt' }))
      ).toMatchObject([
        { path: 'renamed.txt' },
        { path: 'folder/file.ext' }
      ]);
    });

    it('renames file in folder', () => {
      expect(
        reducer(initialState, renameFile({ id: 'folder/file.ext', name: 'renamed.txt' }))
      ).toMatchObject([
        { path: 'file.ext' },
        { path: 'folder/renamed.txt' }
      ]);
    });

    it('can NOT rename a file to an empty name', () => {
      expect(
        reducer(initialState, renameFile({ id: 'dir', name: '' }))
      ).toMatchObject(initialState);
    });
  });


  const initialState = [
    { path: 'file.ext', parentPath: '' },
    { path: 'dir', parentPath: '', type: 'folder' },
    { path: 'dir/file.ext', parentPath: 'dir' },
    { path: 'dir/dir', parentPath: 'dir', type: 'folder' },
    { path: 'dir/dir/file.ext', parentPath: 'dir/dir' }
  ];

  it('renames folder in root', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'dir', name: 'renamedDir' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'renamedDir', parentPath: '' },
      { path: 'renamedDir/file.ext', parentPath: 'renamedDir' },
      { path: 'renamedDir/dir', parentPath: 'renamedDir' },
      { path: 'renamedDir/dir/file.ext', parentPath: 'renamedDir/dir' }
    ]);
  });

  it('can NOT rename a folder to an empty name', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'dir', name: '' }))
    ).toMatchObject(initialState);
  });

  it('renames subfolder in folder', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'dir/dir', name: 'renamedDir' }))
    ).toMatchObject([
      { path: 'file.ext' },
      { path: 'dir' },
      { path: 'dir/file.ext' },
      { path: 'dir/renamedDir' },
      { path: 'dir/renamedDir/file.ext' }
    ]);
  });

  it('returns previous state when folder not found', () => {
    expect(
      reducer(initialState, renameFolder({ id: 'non/existing/dir', name: 'renamedDir' }))
    ).toEqual(initialState);
  });
});


describe('Creating', () => {
  describe('Creating files', () => {

    it('creates the first file in root', () => {
      const emptyState = [];
      const state = reducer(emptyState, createFile({ name: 'file.ext', parentPath: '' }))
      expect(
        state
      ).toMatchObject([
        {
          path: 'file.ext',
          fileName: 'file.ext',
          parentPath: '',
          type: 'file',
          initialContent: null,
          loading: false,
          saved: false,
          line: 0,
          column: 0,
          scrollPosition: 0
        }
      ]);
      state.forEach(checkFileId)
    });

    describe('create a file in a folder', () => {
      const existingFolder = 'folder/folder';
      const initialState = [
        {
          fileId: '12345',
          path: `${existingFolder}/file.ext`
        }
      ];

      it('can create a file', () => {
        const newState = reducer(initialState, createFile({ parentPath: existingFolder, name: 'newFile.ext' }))
        expect(
          newState
        ).toMatchObject([
          ...initialState,
          {
            path: 'folder/folder/newFile.ext',
            fileName: 'newFile.ext',
            parentPath: existingFolder,
            type: 'file',
            initialContent: null,
            loading: false,
            saved: false,
            line: 0,
            column: 0,
            scrollPosition: 0
          }
        ]);
        newState.forEach(checkFileId)
      });

      it('can NOT create a file with an empty name', () => {
        expect(
          reducer(initialState, createFile({ name: '', parentPath: 'dir' }))
        ).toEqual(initialState);
      });

    })

    it('when creating a new file, keeps other files\' properties', () => {
      const initialState = [
        {
          path: 'folder/file.ext',
          fileName: 'file.ext',
          type: 'file',
          initialContent: 'Some initial content',
          loading: false,
          saved: false,
          line: 10,
          column: 20,
          scrollPosition: 30
        }
      ];
      const newState = reducer(initialState, createFile({ parentPath: '', name: 'newFile.ext' }));
      expect(
        newState[0]
      ).toEqual(
        initialState[0]
      );
    });
  });

  describe('Creating folders', () => {
    const existingFolder = 'folder/folder';
    const initialState = [
      {
        fileId: '12345',
        path: `${existingFolder}/file.ext`
      }
    ];

    it('can create a folder', () => {
      const newName = 'my-new-folder';
      const newState = reducer(
        initialState,
        createFolder({ name: newName, parentPath: existingFolder })
      );

      expect(
        newState
      ).toMatchObject([
        ...initialState,
        {
          path: `${existingFolder}/${newName}`,
          fileName: newName,
          parentPath: existingFolder,
          type: 'folder',
          initialContent: null,
          items: [],
          saved: false
        }
      ]);
      newState.forEach(checkFileId);
    });

    it('can NOT create a folder with an empty name', () => {
      expect(
        reducer(initialState, createFolder({ name: '', parentPath: 'dir' }))
      ).toEqual(initialState);
    });

  });
});
