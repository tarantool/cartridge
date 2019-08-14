// @flow

import MonacoEditor from '../MonacoEditor';
import * as React from 'react';
import { Spin, Tree } from 'antd';
import { connect } from 'react-redux';
import { css } from 'react-emotion';
import rest from 'src/api/rest';
import { selectFileTree, selectSelectedFile } from '../../store/selectors/filesSelectors';
import { selectFile } from '../../store/actions/editor.actions';
import { updateFileContent } from '../../store/actions/files.actions';

const { TreeNode, DirectoryTree } = Tree;

const styles = {
  configContainer: css`
    display: flex;
    flex-direction: row;
    flex-wrap: no-wrap;
  `,
  editorContainer: css`
    flex-grow: 1;
    max-width: 800px;
    height: 800px;
    position: relative;s
  `,
  treeContainer: css`
    display: block;
    width: 300px;
    height: 800px;
  `,
  editor: css`
    height: 100%;
    width: 100%;
    display: block;
  `
}

const options = {
  selectOnLineNumbers: true
};

const renderTree = (treeNode: Object, prop: string, render: Function) => {
  const children = (treeNode[prop] || []).map(x => renderTree(x, prop, render))
  return render(treeNode, children)
}

class ConfigEditor extends React.Component{
  state = {
    loading: true
  }

  async componentDidMount(){
    const res = await rest.get(
      '/admin/config',
    );
    this.setState(() => ({
      code: res.data,
      loading: false
    }))
  }

  render(){
    const {
      fileTree,
      fetchingConfigFiles,
      puttingConfigFiles,
      selectedFile,
      dispatch
    } = this.props
    console.log(fileTree)
    return (<div className={styles.configContainer}>
      <div className={styles.treeContainer}>
        <DirectoryTree
          onSelect={(selectedKeys, info) => {
            const selected = selectedKeys.length > 0 ? selectedKeys[0] : null
            if (selected) {
              dispatch(selectFile(selected))
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
                  title={`${item.fileName}${!item.saved ? '   *' : ''}`}
                  key={item.fileId}
                  selectable={item.type === 'file'}
                >
                  {children}
                </TreeNode>
            ))}
        </DirectoryTree>
      </div>
      <div className={styles.editorContainer}>
        <MonacoEditor
          className={styles.editor}
          language={selectedFile && getLanguageByFileName(selectedFile.fileName) || null}
          options={{ ...options, readOnly: !selectedFile }}
          value={selectedFile ? selectedFile.content : 'Select file' }
          onChange={v => dispatch(updateFileContent(selectedFile.fileId, v))}
        />
      </div>
    </div>)
  }
}

export default connect((state, props) => {
  return {
    fileTree: selectFileTree(state.files),
    fetchingConfigFiles: state.ui.fetchingConfigFiles,
    puttingConfigFiles: state.ui.puttingConfigFiles,
    selectedFile: selectSelectedFile(state)
  }
})(ConfigEditor)
