// @flow
import React from 'react';
import { connect } from 'react-redux';
import { bindActionCreators } from 'redux'
import { css, cx } from 'emotion';
import { Button, ControlsPanel, Text, /*IconRefresh*/ } from '@tarantool.io/ui-kit';
import { Tree } from 'antd';
import rest from 'src/api/rest';
import MonacoEditor from 'src/components/MonacoEditor';
import { selectFileTree, selectSelectedFile } from 'src/store/selectors/filesSelectors';
import { selectFile } from 'src/store/actions/editor.actions';
import {
  updateFileContent,
  createFile,
  createFolder,
  renameFile,
  renameFolder,
  deleteFile,
  deleteFolder,
} from 'src/store/actions/files.actions';
import { getLanguageByFileName } from 'src/misc/monacoModelStorage'
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import type { FileItem } from 'src/store/reducers/files.reducer';
import { type State } from 'src/store/rootReducer';

// TODO: delete, it's temporal
let IconRefresh = null;

const { TreeNode, DirectoryTree } = Tree;

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
    width: 255px;
    background-color: #fafafa;
    
    button {
      font-size: .8em;
      color: #000;
    }
  `,
  sidePanelHeading: css`
    min-height: 56px;
    padding: 16px;
    box-sizing: border-box;
  `,
  sidePanelTitle: css`
    
  `,
  mainContent: css`
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    padding: 16px;
    box-sizing: border-box;
  `,
  cardMargin: css`
    padding: 24px 16px;
    min-width: 1000px;
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
}

type CodeProps = {
  className?: string,
  fileTree: Array<TreeFileItem>,
  fetchingConfigFiles: boolean,
  puttingConfigFiles: boolean,
  selectedFile: FileItem | null,
  selectFile: Function,
  updateFileContent: Function,
}

class Code extends React.Component<CodeProps, CodeState> {
  state = {
    loading: true,
    code: null,
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

  render() {
    const {
      className,
      fileTree = [],
      selectedFile,
      selectFile,
      updateFileContent,
      createFile,
      createFolder,
      renameFile,
      renameFolder,
      deleteFile,
      deleteFolder,
      dispatch
    } = this.props;

    console.log({
      createFile,
      createFolder,
      renameFile,
      renameFolder,
      deleteFile,
      deleteFolder,
    });

    return (
      <div className={cx(styles.area, className)}>
        <div className={styles.sidePanel}>
          <div className={styles.sidePanelHeading}>
            <Text variant='h4' className={styles.sidePanelTitle}>Files</Text>
          </div>
          <DirectoryTree
            onSelect={(selectedKeys, info) => {
              const selected = selectedKeys.length > 0 ? selectedKeys[0] : null
              if (selected) {
                selectFile(selected)
              }
            }}
          >
            {fileTree.map(
              x => renderTree(
                x,
                'items',
                (item, children) =>
                  <TreeNode
                    isLeaf={item.items.length === 0}
                    title={<>
                      {item.fileName}{!item.saved ? '   *' : ''}
                      <span style={{ marginLeft: '.5em' }}>
                        {item.type === 'folder' && <>
                          <button
                            onClick={() => createFolder({ name: new Date().getSeconds(), parentId: item.fileId })}
                          >+Folder</button>
                          <button
                            onClick={() => createFile({ name: new Date().getSeconds(), parentId: item.fileId })}
                          >+File</button>
                        </>}

                        <button
                          style={{ background: 'gold' }}
                          onClick={
                            () => dispatch(
                              (item.type === 'folder' ? renameFolder : renameFile)({
                                id: item.fileId, name: new Date().getSeconds()
                              })
                            )
                          }
                        >Rename</button>

                        <button
                          onClick={() => (item.type === 'folder' ? deleteFolder : deleteFile)({ id: item.fileId })}
                        >Delete</button>
                      </span>
                    </>}
                    key={item.fileId}
                    selectable={item.type === 'file'}
                  >
                    {children}
                  </TreeNode>
              )
            )}
          </DirectoryTree>
        </div >
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
                  onClick={() => null}
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
            onChange={v => selectedFile && updateFileContent(selectedFile.fileId, v)}
          />
        </div>
      </div >
    );
  }
}

const mapStateToProps = (state: State) => {
  console.log('MAP STATE TO PROPS', {
    fileTree: selectFileTree(state.files),
    fetchingConfigFiles: state.ui.fetchingConfigFiles,
    puttingConfigFiles: state.ui.puttingConfigFiles,
    selectedFile: selectSelectedFile(state)
  });
  return {
    fileTree: selectFileTree(state.files),
    fetchingConfigFiles: state.ui.fetchingConfigFiles,
    puttingConfigFiles: state.ui.puttingConfigFiles,
    selectedFile: selectSelectedFile(state)
  }
};

const mapDispatch = dispatch => {
  return {
    dispatch,
    ...bindActionCreators(
      {
        createFile,
        createFolder,
        renameFile,
        renameFolder,
        deleteFile,
        deleteFolder,
        selectFile,
        updateFileContent
      },
      dispatch
    )
  };
};

export default connect(mapStateToProps, mapDispatch)(Code)
