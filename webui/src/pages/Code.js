// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import {
  Button,
  ConfirmModal,
  ControlsPanel,
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
    min-height: 56px;
    padding: 16px;
    box-sizing: border-box;
  `,
  sidePanelTitle: css`
    
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

  getFileById = (id: ?string) => this.props.fileTree.find(({ fileId }) => fileId === id);

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

    if (fileOperationObject) {
      dispatch(createFile({ parentId: fileOperationObject, name }));

      this.setState({
        fileOperationType: null,
        fileOperationObject: null
      });
    }
  }

  handleFolderCreateClick = (id: string) => this.setState({
    fileOperationType: 'createFolder',
    fileOperationObject: id
  });

  handleFolderCreateConfirm = (name: string) => {
    const { dispatch } = this.props;
    const { fileOperationObject } = this.state;

    if (fileOperationObject) {
      dispatch(createFolder({ parentId: fileOperationObject, name }));

      this.setState({
        fileOperationType: null,
        fileOperationObject: null
      });
    }
  }

  handleFileOperationCancel = () => this.setState({
    fileOperationType: null,
    fileOperationObject: null
  });

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
          </div>
          <Scrollbar className={styles.treeScrollWrap}>
            <FileTree
              tree={fileTree}
              selectedFile={selectedFile}
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
            <Text className={styles.filePath}>{selectedFile && selectedFile.path}</Text>
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
            onChange={v => selectedFile && dispatch(updateFileContent(selectedFile.fileId, v))}
          />
        </div>
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
              {` ${operableFile && operableFile.type}`}
            </Text>
          </PopupBody>
        </ConfirmModal>
        <InputModal
          title='Rename file'
          text={(
            <React.Fragment>
              {`Enter the new name of the ${operableFile && operableFile.type}: `}
              <Text className={styles.popupFileName}>{operableFile && operableFile.fileName}</Text>
            </React.Fragment>
          )}
          confirmText='Rename'
          initialValue={operableFile && operableFile.fileName}
          onConfirm={this.handleFileRenameConfirm}
          onClose={this.handleFileOperationCancel}
          visible={fileOperationType === 'rename'}
        />
        <InputModal
          title='Create file'
          text='Enter the name of the new file and its extension:'
          confirmText='Create'
          initialValue={'.lua'}
          onConfirm={this.handleFileCreateConfirm}
          onClose={this.handleFileOperationCancel}
          visible={fileOperationType === 'createFile'}
        />
        <InputModal
          title='Create folder'
          text='Enter the name of the new folder:'
          confirmText='Create'
          onConfirm={this.handleFolderCreateConfirm}
          onClose={this.handleFileOperationCancel}
          visible={fileOperationType === 'createFolder'}
        />
      </div>
    );
  }
}

const mapStateToProps = (state: State) => {
  return {
    fileTree: selectFileTree(state.files),
    fetchingConfigFiles: state.ui.fetchingConfigFiles,
    puttingConfigFiles: state.ui.puttingConfigFiles,
    selectedFile: selectSelectedFile(state)
  }
};

export default connect(mapStateToProps)(Code)
