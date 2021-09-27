// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from '@emotion/css';
import {
  Button,
  ConfirmModal,
  IconCreateFile,
  IconCreateFolder,
  IconRefresh,
  Text,
  colors,
} from '@tarantool.io/ui-kit';

import { FileTree } from 'src/components/FileTree';
import MonacoEditor from 'src/components/MonacoEditor';
import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import { PageLayout } from 'src/components/PageLayout';
import { getFileIdForMonaco, getLanguageByFileName } from 'src/misc/monacoModelStorage';
import { selectFile } from 'src/store/actions/editor.actions';
import {
  applyFiles,
  createFile,
  createFolder,
  deleteFile,
  deleteFolder,
  fetchConfigFiles,
  renameFile,
  renameFolder,
  setIsContentChanged,
  validateConfigFiles,
} from 'src/store/actions/files.actions';
import type { FileItem } from 'src/store/reducers/files.reducer';
import type { State } from 'src/store/rootReducer';
import { selectFilePaths, selectFileTree, selectSelectedFile } from 'src/store/selectors/filesSelectors';
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';

import noFileIcon from './no-file.png';

const options = {
  fixedOverflowWidgets: true,
  automaticLayout: true,
  selectOnLineNumbers: true,
};

const styles = {
  area: css`
    display: flex;
    flex-direction: row;
    flex-grow: 1;
    border-radius: 4px;
    overflow: hidden;
    background-color: #ffffff;
  `,
  sidePanel: css`
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    width: 274px;
    background-color: #fafafa;
  `,
  sidePanelHeading: css`
    display: flex;
    align-items: center;
    min-height: 56px;
    padding: 15px;
    box-sizing: border-box;
  `,
  buttonsPanel: css`
    display: flex;
    flex-wrap: nowrap;
    align-items: center;
    padding-left: 2px;
  `,
  fileActionBtn: css`
    margin-left: 4px;
  `,
  mainContent: css`
    flex-grow: 1;
    display: flex;
    flex-direction: column;
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
    margin: 20px;
  `,
  currentPath: css`
    color: ${colors.dark40};
  `,
  editor: css`
    flex-grow: 1;
    overflow: hidden;
  `,
  splash: css`
    display: flex;
    flex-grow: 1;
    align-items: center;
    justify-content: center;
    flex-direction: column;
  `,
  selectFileIcon: css`
    width: 120px;
    height: 96px;
    margin-bottom: 20px;
  `,
  selectFileText: css`
    font-size: 14px;
    font-weight: 400;
    color: ${colors.dark65};
  `,
};

type CodeState = {
  loading: boolean,
  fileOperationType: 'createFile' | 'createFolder' | 'rename' | 'delete' | null,
  fileOperationObject: ?string,
  isReloadConfirmOpened: boolean,
};

type CodeProps = {
  fileTree: Array<TreeFileItem>,
  files: Array<FileItem>,
  filePaths: Array<string>,
  fetchingConfigFiles: boolean,
  puttingConfigFiles: boolean,
  selectedFile: FileItem | null,
  dispatch: Function,
  error: any,
};

class Code extends React.Component<CodeProps, CodeState> {
  state = {
    loading: false,
    fileOperationType: null,
    fileOperationObject: null,
    isReloadConfirmOpened: false,
  };

  static getDerivedStateFromProps(nextProps, prevState) {
    if (prevState.loading === true && nextProps.fetchingConfigFiles === false) {
      return {
        loading: false,
      };
    }
    return null;
  }

  async componentDidMount() {
    const { dispatch, files } = this.props;

    if (files.length > 0) {
      return;
    }
    dispatch(fetchConfigFiles(true));
    this.setState({ loading: true });
  }

  getFileById = (id: ?string) => this.props.files.find((file) => file.path === id);

  handleFileDeleteClick = (id: string) =>
    this.setState({
      fileOperationType: 'delete',
      fileOperationObject: id,
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
        fileOperationObject: null,
      });
    }
  };

  handleFileRenameClick = (id: string) =>
    this.setState({
      fileOperationType: 'rename',
      fileOperationObject: id,
    });

  handleReloadClick = () =>
    this.setState({
      isReloadConfirmOpened: true,
    });

  handleApplyClick = () => {
    this.props.dispatch(applyFiles());
  };

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
        fileOperationObject: null,
      });
    }
  };

  handleFileCreateClick = (id: string) =>
    this.setState({
      fileOperationType: 'createFile',
      fileOperationObject: id,
    });

  handleFileCreateConfirm = (name: string) => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    dispatch(createFile({ parentPath: fileOperationObject, name }));

    this.setState({
      fileOperationType: null,
      fileOperationObject: null,
    });
  };

  handleFolderCreateClick = (id: string) =>
    this.setState({
      fileOperationType: 'createFolder',
      fileOperationObject: id,
    });

  handleFolderCreateConfirm = (name: string) => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    dispatch(createFolder({ parentPath: fileOperationObject, name }));

    this.setState({
      fileOperationType: null,
      fileOperationObject: null,
    });
  };

  handleFileOperationCancel = () =>
    this.setState({
      fileOperationType: null,
      fileOperationObject: null,
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
  };

  handleSetIsContentChanged = (isChanged: boolean) => {
    const { selectedFile, dispatch } = this.props;

    if (!selectedFile) {
      return;
    }
    const fileId = selectedFile.fileId;

    dispatch(setIsContentChanged(fileId, isChanged));
  };

  validateCode = () => {
    const { dispatch } = this.props;

    dispatch(validateConfigFiles());
  };

  render() {
    const {
      fileTree = [],
      filePaths,
      fetchingConfigFiles,
      puttingConfigFiles,
      selectedFile,
      dispatch,
      error,
    } = this.props;

    const { fileOperationType, fileOperationObject, isReloadConfirmOpened, loading } = this.state;

    const operableFile = this.getFileById(fileOperationObject);

    if (error) {
      return <PageDataErrorMessage error={error} />;
    }

    return (
      <PageLayout
        heading="Code"
        wide
        topRightControls={[
          <Button
            data-cy={'meta-test__Reload'}
            key="Reload"
            text="Reload"
            size="l"
            className={
              !loading && fetchingConfigFiles ? 'meta-test__Code__reload_loading' : 'meta-test__Code__reload_idle'
            }
            loading={!loading && fetchingConfigFiles}
            onClick={this.handleReloadClick}
            icon={IconRefresh}
            intent="base"
          />,
          <Button
            data-cy={'meta-test__Validate'}
            key="Validate"
            text="Validate"
            intent="base"
            size="l"
            onClick={this.validateCode}
          />,
          <Button
            data-cy={'meta-test__Apply'}
            key="Apply"
            onClick={this.handleApplyClick}
            className={puttingConfigFiles ? 'meta-test__Code__apply_loading' : 'meta-test__Code__apply_idle'}
            text="Apply"
            intent="primary"
            loading={puttingConfigFiles}
            size="l"
            disabled={false}
          />,
        ]}
      >
        <div className={cx('meta-test__Code', styles.area)}>
          <div className={styles.sidePanel}>
            <div className={styles.sidePanelHeading}>
              <Text variant="h4">Files</Text>
              <div className={styles.buttonsPanel}>
                <Button
                  className={cx(styles.fileActionBtn, 'meta-test__addFolderBtn')}
                  intent="plain"
                  size="m"
                  icon={IconCreateFolder}
                  onClick={() => this.handleFolderCreateClick('')}
                  title="Create folder"
                />
                <Button
                  className={cx(styles.fileActionBtn, 'meta-test__addFileBtn')}
                  intent="plain"
                  size="m"
                  icon={IconCreateFile}
                  onClick={() => this.handleFileCreateClick('')}
                  title="Create file"
                />
              </div>
            </div>
            <FileTree
              className={'meta-test__Code__FileTree'}
              initiallyExpanded
              tree={fileTree}
              filePaths={filePaths}
              selectedFile={selectedFile}
              fileOperation={fileOperationType}
              operationObject={fileOperationObject}
              onOperationConfirm={this.handleFileOperationConfirm}
              onOperationCancel={this.handleFileOperationCancel}
              onFileOpen={(id) => dispatch(selectFile(id))}
              onFileCreate={this.handleFileCreateClick}
              onFolderCreate={this.handleFolderCreateClick}
              onDelete={this.handleFileDeleteClick}
              onRename={this.handleFileRenameClick}
            />
          </div>
          <div className={styles.mainContent}>
            <div className={styles.panel}>
              <Text className={styles.currentPath} variant="p" tag="span">
                {selectedFile && selectedFile.path.replace(/\//g, ' / ')}
              </Text>
            </div>
            {selectedFile ? (
              <MonacoEditor
                className={styles.editor}
                language={(selectedFile && getLanguageByFileName(selectedFile.fileName)) || null}
                options={{
                  ...options,
                  readOnly: !selectedFile,
                }}
                fileId={selectedFile ? getFileIdForMonaco(selectedFile.fileId) : null}
                initialValue={selectedFile ? selectedFile.initialContent : 'Select or add a file'}
                isContentChanged={selectedFile ? !selectedFile.saved : null}
                setIsContentChanged={this.handleSetIsContentChanged}
              />
            ) : (
              <div className={styles.splash}>
                <img className={styles.selectFileIcon} src={noFileIcon} alt="No selected file" />
                <Text className={styles.selectFileText}>Please select a file</Text>
              </div>
            )}
          </div>
          {operableFile && typeof operableFile.type === 'string' && (
            <ConfirmModal
              title={`Delete ${operableFile.type}`}
              className="meta-test__deleteModal"
              visible={fileOperationType === 'delete'}
              onCancel={this.handleFileOperationCancel}
              onConfirm={this.handleFileDeleteConfirm}
            >
              <Text>
                {'Are you sure you want to delete the '}
                <Text className={styles.popupFileName}>{operableFile && operableFile.fileName}</Text>
                {` ${operableFile.type}`}
              </Text>
            </ConfirmModal>
          )}
          {isReloadConfirmOpened && (
            <ConfirmModal
              title="Reload files"
              onCancel={() => this.setState({ isReloadConfirmOpened: false })}
              onConfirm={() => {
                this.props.dispatch(fetchConfigFiles());
                this.setState({ isReloadConfirmOpened: false });
              }}
            >
              <Text>
                Are you sure you want to reload all the files?
                <br />
                All unsaved changes will be reset
              </Text>
            </ConfirmModal>
          )}
        </div>
      </PageLayout>
    );
  }
}

const mapStateToProps = (state: State) => ({
  fileTree: selectFileTree(state.codeEditor.files),
  filePaths: selectFilePaths(state.codeEditor.files),
  files: state.codeEditor.files,
  fetchingConfigFiles: state.ui.fetchingConfigFiles,
  puttingConfigFiles: state.ui.puttingConfigFiles,
  selectedFile: selectSelectedFile(state.codeEditor),
  error: state.codeEditor.editor.error,
});

export default connect(mapStateToProps)(Code);
