// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import { throttle } from 'lodash';
import {
  Button,
  ConfirmModal,
  ControlsPanel,
  IconCreateFolder,
  IconCreateFile,
  IconRefresh,
  Input,
  Modal,
  PopupBody,
  PopupFooter,
  Text,
  Scrollbar
} from '@tarantool.io/ui-kit';
import rest from 'src/api/rest';
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
  renameFolder,
  renameFile,
  updateFileContent
} from 'src/store/actions/files.actions';
import { getLanguageByFileName } from 'src/misc/monacoModelStorage'
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import type { FileItem } from 'src/store/reducers/files.reducer';
import { type State } from 'src/store/rootReducer';

const options = {
  fixedOverflowWidgets: true,
  automaticLayout: true,
  selectOnLineNumbers: true
};

const renderTree = (treeNode: Object, prop: string, render: Function) => {
  const children = (treeNode[prop] || []).map(x => renderTree(x, prop, render))
  return render(treeNode, children)
}

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
  `
};

type CodeState = {
  loading: boolean,
  code: ?string,
  fileOperationType: 'createFile' | 'createFolder' | 'rename' | 'delete' | null,
  fileOperationObject: ?string
}

type CodeProps = {
  className?: string,
  fileTree: Array<TreeFileItem>,
  files: Array<FileItem>,
  fetchingConfigFiles: boolean,
  puttingConfigFiles: boolean,
  selectedFile: FileItem | null,
  dispatch: Function,
}

class Code extends React.Component<CodeProps, CodeState> {
  state = {
    loading: true,
    code: null,
    fileOperationType: null,
    fileOperationObject: null
  }

  async componentDidMount() {
    const res = await rest.get(
      '/admin/config'
    );
    this.setState(() => ({
      code: res.data,
      loading: false
    }))
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

  _throttledContentUpdatersByFileId = {};

  handleContentChange = (content: string) => {
    const {
      selectedFile,
      dispatch
    } = this.props;

    if (!selectedFile) {
      return;
    }

    const fileId = selectedFile.fileId;

    // each file should have its own (separate) updater
    let throttledUpdater = this._throttledContentUpdatersByFileId[fileId];
    if (!throttledUpdater) {
      throttledUpdater = throttle(
        v => dispatch(updateFileContent(fileId, v)),
        2000,
        { leading: false }
      )
      this._throttledContentUpdatersByFileId[fileId] = throttledUpdater;
    }
    throttledUpdater(content);
  }

  render() {
    const {
      className,
      fileTree = [],
      selectedFile,
      dispatch
    } = this.props;

    const {
      fileOperationType,
      fileOperationObject
    } = this.state;

    const operableFile = this.getFileById(fileOperationObject);

    return (
      <div className={cx(styles.area, className)}>
        <div className={styles.sidePanel}>
          <div className={styles.sidePanelHeading}>
            <Text variant='h4' className={styles.sidePanelTitle}>Files</Text>
            <div className={styles.buttonsPanel}>
              <Button
                className={styles.fileActionBtn}
                intent='plain'
                size='xs'
                icon={IconCreateFolder}
                onClick={() => this.handleFolderCreateClick('')}
              />
              <Button
                className={cx(styles.fileActionBtn)}
                intent='plain'
                size='xs'
                icon={IconCreateFile}
                onClick={() => this.handleFileCreateClick('')}
              />
            </div>
          </div>
          <Scrollbar className={styles.treeScrollWrap}>
            <FileTree
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
                  text='Revert'
                  size='s'
                  onClick={() => null}
                  icon={IconRefresh}
                  intent='secondary'
                />,
                <Button
                  onClick={this.handleApplyClick}
                  text='Apply'
                  intent='primary'
                  size='s'
                  disabled={false}
                />
              ]}
            />
          </div>
          <MonacoEditor
            className={styles.editor}
            language={selectedFile && getLanguageByFileName(selectedFile.fileName) || null}
            options={{
              ...options,
              readOnly: !selectedFile
            }}
            fileId={selectedFile ? `inmemory://${selectedFile.fileId}.lua` : null}
            value={selectedFile ? selectedFile.content : 'Select file'}
            onChange={this.handleContentChange}
          />
        </div>
        {operableFile && typeof operableFile.type === 'string' && (
          <ConfirmModal
            title='Delete file'
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
      </div>
    );
  }
}

const mapStateToProps = (state: State) => {
  return {
    fileTree: selectFileTree(state.files),
    files: state.files,
    fetchingConfigFiles: state.ui.fetchingConfigFiles,
    puttingConfigFiles: state.ui.puttingConfigFiles,
    selectedFile: selectSelectedFile(state)
  }
};

export default connect(mapStateToProps)(Code)
