// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import { Button, ControlsPanel, Text, IconRefresh } from '@tarantool.io/ui-kit';
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import type { FileItem } from 'src/store/reducers/files.reducer';
import { FileTreeElement } from './FileTreeElement';

const renderTree = (treeNode: Object, prop: string, render: Function, level: number) => {
  const children = (treeNode[prop] || []).map(x => renderTree(x, prop, render, level + 1))
  return render(treeNode, children, level)
}

const styles = {
  tree: css`
    padding: 0;
    margin: 0;
    list-style: none;
  `
};

type FileTreeProps = {
  className?: string,
  tree: Array<TreeFileItem>,
  selectedFile: FileItem | null,
  onFileCreate: (parentId: string) => void,
  onDelete: (id: string) => void,
  onFileOpen: (id: string) => void,
  onFolderCreate: (parentId: string) => void,
  onRename: (id: string) => void,
};

type FileTreeState = {
  expandedEntries: string[]
};

export class FileTree extends React.Component<FileTreeProps, FileTreeState> {
  state = {
    expandedEntries: []
  };

  // TODO: по componentWillUpdate убрать из списка файлы, которые были удалены
  expandEntry = (id: string) => {
    const { expandedEntries } = this.state;

    if (expandedEntries.includes(id)) {
      this.setState({
        expandedEntries: expandedEntries.filter(i => i !== id )
      });
    } else {
      this.setState({
        expandedEntries: [...expandedEntries, id]
      });
    }
  }

  render() {
    const {
      className,
      tree = [],
      selectedFile,
      onDelete,
      onFileCreate,
      onFileOpen,
      onFolderCreate,
      onRename
    } = this.props;

    const { expandedEntries } = this.state;

    return (
      <ul className={cx(styles.tree, className)}>
        {tree.map(
          x => renderTree(
            x,
            'items',
            (item, children, level) => (
              <FileTreeElement
                key={item.path}
                file={item}
                active={selectedFile && (selectedFile.path === item.path)}
                level={level}
                expanded={expandedEntries.includes(item.path)}
                onDelete={onDelete}
                onExpand={this.expandEntry}
                onFileCreate={onFileCreate}
                onFileOpen={onFileOpen}
                onFolderCreate={onFolderCreate}
                onRename={onRename}
              >
                {children}
              </FileTreeElement>
            ),
            0
          )
        )}
      </ul>
    );
  }
}
