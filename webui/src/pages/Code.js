// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import {
  Button,
  ConfirmModal,
  ControlsPanel,
  IconCreateFolder,
  IconCreateFile,
  IconRefresh,
  PopupBody,
  Text,
  Scrollbar
} from '@tarantool.io/ui-kit';
import { InputModal } from 'src/components/InputModal';
import MonacoEditor from 'src/components/MonacoEditor';
import { FileTree } from 'src/components/FileTree';
import { selectFileTree, selectSelectedFile } from 'src/store/selectors/filesSelectors';
import { selectFile } from 'src/store/actions/editor.actions';
import {
  applyFiles,
  createFile,
  createFolder,
  deleteFile,
  deleteFolder,
  fetchConfigFiles,
  renameFolder,
  renameFile,
  setIsContentChanged
} from 'src/store/actions/files.actions';
import { getLanguageByFileName, getFileIdForMonaco } from 'src/misc/monacoModelStorage'
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import type { FileItem } from 'src/store/reducers/files.reducer';
import { type State } from 'src/store/rootReducer';
import { IconFileWithCode } from 'src/components/Icon/icons/IconFileWithCode';

const options = {
  fixedOverflowWidgets: true,
  automaticLayout: true,
  selectOnLineNumbers: true
};

const styles = {
  area: css`
    display: flex;
    flex-direction: row;
    height: calc(100% - 69px - 32px);
    margin: 16px;
    border-radius: 4px;
    overflow: hidden;
    background-color: #ffffff;
  `,
  areaWithPane: css`
    height: calc(100% - 69px - 112px - 16px);
  `,
  sidePanel: css`
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    width: 255px;
    background-color: #fafafa;
  `,
  sidePanelHeading: css`
    display: flex;
    min-height: 56px;
    padding: 16px;
    box-sizing: border-box;
  `,
  sidePanelTitle: css`

  `,
  buttonsPanel: css`
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
    padding-left: 6px;
  `,
  fileActionBtn: css`
    line-height: 16px;
    padding: 0 2px;
  `,
  treeScrollWrap: css`
    flex-grow: 1;
  `,
  mainContent: css`
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    padding: 16px;
    box-sizing: border-box;
    overflow: hidden;
  `,
  cardMargin: css`
    padding: 24px 16px;
    min-width: 1000px;
  `,
  popupFileName: css`
    font-weight: 600;
  `,
  title: css`
    margin-left: 16px;
  `,
  panel: css`
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    padding-bottom: 16px;
    margin-bottom: 16px;
    border-bottom: 1px solid #E8E8E8;
  `,
  editor: css`
    flex-grow: 1;
  `,
  splash: css`
    display: flex;
    flex-direction: column;
    flex-grow: 1;
    align-items: center;
    justify-content: center;
    text-align: center;
    color: rgba(0, 0, 0, 0.25);
    font-size: 14px;
  `,
  splashIcon: css`
    width: 35px;
    height: 35px;
    margin-bottom: 16px;
  `
};

type CodeState = {
  loading: boolean,
  fileOperationType: 'createFile' | 'createFolder' | 'rename' | 'delete' | null,
  fileOperationObject: ?string,
  isReloadConfirmOpened: boolean,
}

type CodeProps = {
  className?: string,
  fileTree: Array<TreeFileItem>,
  files: Array<FileItem>,
  isDemoPanelPresent: boolean,
  fetchingConfigFiles: boolean,
  puttingConfigFiles: boolean,
  selectedFile: FileItem | null,
  dispatch: Function,
}

class Code extends React.Component<CodeProps, CodeState> {
  state = {
    loading: false,
    fileOperationType: null,
    fileOperationObject: null,
    isReloadConfirmOpened: false
  }

  static getDerivedStateFromProps(nextProps, prevState) {
    if (prevState.loading === true && nextProps.fetchingConfigFiles === false) {
      return {
        loading: false
      };
    }
    return null;
  }

  async componentDidMount() {
    const { dispatch, files } = this.props;

    if (files.length > 0) {
      return;
    }
    dispatch(fetchConfigFiles());
    this.setState({ loading: true });
  }

  getFileById = (id: ?string) => this.props.files.find(file => file.path === id);

  handleFileDeleteClick = (id: string) => this.setState({
    fileOperationType: 'delete',
    fileOperationObject: id
  });

  handleFileDeleteConfirm = () => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    if (fileOperationObject) {
      const file = this.getFileById(fileOperationObject);

      dispatch(
        file && file.type === 'folder'
          ? deleteFolder({ id: fileOperationObject })
          : deleteFile({ id: fileOperationObject })
      );

      this.setState({
        fileOperationType: null,
        fileOperationObject: null
      });
    }
  }

  handleFileRenameClick = (id: string) => this.setState({
    fileOperationType: 'rename',
    fileOperationObject: id
  });

  handleReloadClick = () => this.setState({
    isReloadConfirmOpened: true
  })

  handleApplyClick = () => {
    this.props.dispatch(applyFiles());
  }

  handleFileRenameConfirm = (name: string) => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    if (fileOperationObject) {
      const file = this.getFileById(fileOperationObject);

      dispatch(
        file && file.type === 'folder'
          ? renameFolder({ id: fileOperationObject, name })
          : renameFile({ id: fileOperationObject, name })
      );

      this.setState({
        fileOperationType: null,
        fileOperationObject: null
      });
    }
  }

  handleFileCreateClick = (id: string) => this.setState({
    fileOperationType: 'createFile',
    fileOperationObject: id
  });

  handleFileCreateConfirm = (name: string) => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    dispatch(createFile({ parentPath: fileOperationObject, name }));

    this.setState({
      fileOperationType: null,
      fileOperationObject: null
    });
  }

  handleFolderCreateClick = (id: string) => this.setState({
    fileOperationType: 'createFolder',
    fileOperationObject: id
  });

  handleFolderCreateConfirm = (name: string) => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    dispatch(createFolder({ parentPath: fileOperationObject, name }));

    this.setState({
      fileOperationType: null,
      fileOperationObject: null
    });
  }

  handleFileOperationCancel = () => this.setState({
    fileOperationType: null,
    fileOperationObject: null
  });

  handleFileOperationConfirm = (name: string) => {
    const { fileOperationType } = this.state;

    switch (fileOperationType) {
      case 'rename':
        return this.handleFileRenameConfirm(name);

      case 'createFile':
        return this.handleFileCreateConfirm(name);

      case 'createFolder':
        return this.handleFolderCreateConfirm(name);
    }
  }

  handleSetIsContentChanged = (isChanged: boolean) => {
    const {
      selectedFile,
      dispatch
    } = this.props;

    if (!selectedFile) {
      return;
    }
    const fileId = selectedFile.fileId;

    dispatch(setIsContentChanged(fileId, isChanged));
  }

  render() {
    const {
      className,
      fileTree = [],
      isDemoPanelPresent,
      fetchingConfigFiles,
      puttingConfigFiles,
      selectedFile,
      dispatch
    } = this.props;

    const {
      fileOperationType,
      fileOperationObject,
      isReloadConfirmOpened,
      loading
    } = this.state;

    const operableFile = this.getFileById(fileOperationObject);

    return (
      <React.Fragment>
        <div
          className={cx(
            styles.area,
            { [styles.areaWithPane]: isDemoPanelPresent },
            className
          )}
        >
          <div className={styles.sidePanel}>
            <div className={styles.sidePanelHeading}>
              <Text variant='h4' className={styles.sidePanelTitle}>Files</Text>
              <div className={styles.buttonsPanel}>
                <Button
                  className={cx(styles.fileActionBtn, 'meta-test__addFolderBtn')}
                  intent='plain'
                  size='xs'
                  icon={IconCreateFolder}
                  onClick={() => this.handleFolderCreateClick('')}
                  title='Create folder'
                />
                <Button
                  className={cx(styles.fileActionBtn, 'meta-test__addFileBtn')}
                  intent='plain'
                  size='xs'
                  icon={IconCreateFile}
                  onClick={() => this.handleFileCreateClick('')}
                  title='Create file'
                />
              </div>
            </div>
            <Scrollbar className={styles.treeScrollWrap}>
              <FileTree
                initiallyExpanded
                tree={fileTree}
                selectedFile={selectedFile}
                fileOperation={fileOperationType}
                operationObject={fileOperationObject}
                onOperationConfirm={this.handleFileOperationConfirm}
                onOperationCancel={this.handleFileOperationCancel}
                onFileOpen={id => dispatch(selectFile(id))}
                onFileCreate={this.handleFileCreateClick}
                onFolderCreate={this.handleFolderCreateClick}
                onDelete={this.handleFileDeleteClick}
                onRename={this.handleFileRenameClick}
              />
            </Scrollbar>
          </div>
          <div className={styles.mainContent}>

            <div className={styles.panel}>
              <Text>{selectedFile && selectedFile.path}</Text>
              <ControlsPanel
                thin
                controls={[
                  <Button
                    text='Reload'
                    size='s'
                    className={
                      !loading && fetchingConfigFiles
                        ? 'meta-test__Code__reload_loading'
                        : 'meta-test__Code__reload_idle'
                    }
                    loading={!loading && fetchingConfigFiles}
                    onClick={this.handleReloadClick}
                    icon={IconRefresh}
                    intent='secondary'
                  />,
                  <Button
                    onClick={this.handleApplyClick}
                    className={
                      puttingConfigFiles
                        ? 'meta-test__Code__apply_loading'
                        : 'meta-test__Code__apply_idle'
                    }
                    text='Apply'
                    intent='primary'
                    loading={puttingConfigFiles}
                    size='s'
                    disabled={false}
                  />
                ]}
              />
            </div>
            {selectedFile ?
              <>
                <MonacoEditor
                  className={styles.editor}
                  language={selectedFile && getLanguageByFileName(selectedFile.fileName) || null}
                  options={{
                    ...options,
                    readOnly: !selectedFile
                  }}
                  fileId={selectedFile ? getFileIdForMonaco(selectedFile.fileId) : null}
                  initialValue={selectedFile ? selectedFile.initialContent : 'Select or add a file'}
                  isContentChanged={selectedFile ? !selectedFile.saved : null}
                  setIsContentChanged={this.handleSetIsContentChanged}
                />
              </>
              :
              <div className={styles.splash}>
                <IconFileWithCode className={styles.splashIcon} />
                Please select a file
              </div>
            }
          </div>
          {operableFile && typeof operableFile.type === 'string' && (
            <ConfirmModal
              title='Delete file'
              className='meta-test__deleteModal'
              visible={fileOperationType === 'delete'}
              onCancel={this.handleFileOperationCancel}
              onConfirm={this.handleFileDeleteConfirm}
            >
              <PopupBody>
                <Text>
                  {'Are you sure you want to delete the '}
                  <Text className={styles.popupFileName}>{operableFile && operableFile.fileName}</Text>
                  {` ${operableFile.type}`}
                </Text>
              </PopupBody>
            </ConfirmModal>
          )}
          {isReloadConfirmOpened && (
            <ConfirmModal
              title='Reload files'
              onCancel={() => this.setState({ isReloadConfirmOpened: false })}
              onConfirm={() => {
                this.props.dispatch(fetchConfigFiles());
                this.setState({ isReloadConfirmOpened: false });
              }}
            >
              <PopupBody>
                <Text>
                  Are you sure you want to reload all the files?
                  <br />
                  All unsaved changes will be reset
                </Text>
              </PopupBody>
            </ConfirmModal>
          )}
        </div>
      </React.Fragment>
    );
  }
}

const mapStateToProps = (state: State) => {
  const { app: { clusterSelf } } = state;

  return {
    fileTree: selectFileTree(state.codeEditor.files),
    files: state.codeEditor.files,
    fetchingConfigFiles: state.ui.fetchingConfigFiles,
    puttingConfigFiles: state.ui.puttingConfigFiles,
    selectedFile: selectSelectedFile(state.codeEditor),
    isDemoPanelPresent: !!clusterSelf && clusterSelf.demo_uri
  }
};

export default connect(mapStateToProps)(Code)
