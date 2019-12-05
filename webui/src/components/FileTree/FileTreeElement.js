// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import {
  Button,
  ControlsPanel,
  DotIndicator,
  IconChevron,
  IconCreateFolder,
  IconCreateFile,
  IconDelete,
  IconEdit,
  IconFile,
  IconFolder,
  Text
} from '@tarantool.io/ui-kit';
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import type { FileItem } from 'src/store/reducers/files.reducer';

const styles = {
  element: css`
    position: relative;
    display: flex;
    flex-wrap: nowrap;
    justify-content: flex-start;
    align-items: center;
    height: 34px;
    padding-right: 8px;
    user-select: none;
    cursor: pointer;

    &:hover {
      background-color: #ffffff;
    }

    .FileTreeElement__btns {
      display: none;
    }

    &:hover > .FileTreeElement__btns {
      display: flex;
    }
  `,
  active: css`
    background-color: #ffffff;
  `,
  deleted: css`
    text-decoration: line-through;
    color: #aaa;
  `,
  fileName: css`
    overflow: hidden;
    text-overflow: ellipsis;
  `,
  iconChevron: css`
    margin: 4px;
    fill: rgba(0, 0, 0, 0.65);
  `,
  iconChevronFile: css`
    visibility: hidden;
  `,
  fileIcon: css`
    margin: 4px;
  `,
  buttonsPanel: css`
    position: absolute;
    top: calc(50% - 9px);
    right: 8px;
    display: flex;
    flex-wrap: nowrap;
    background-color: #ffffff;
  `,
  fileActionBtn: css`
    line-height: 16px;
    padding: 0 2px;
  `,
  fileActionBtnMargin: css`
    margin-right: 8px;
  `
};

type FileTreeElementProps = {
  active?: boolean,
  children?: React.Node,
  className?: string,
  expanded?: boolean,
  file: FileItem,
  level?: number,
  onDelete: (id: string) => void,
  onExpand: (id: string) => void,
  onFileCreate: (parentId: string) => void,
  onFileOpen: (id: string) => void,
  onFolderCreate: (parentId: string) => void,
  onRename: (id: string) => void
}

export const FileTreeElement = (
  {
    active,
    className,
    children,
    expanded,
    file,
    level,
    onDelete,
    onExpand,
    onFileCreate,
    onFileOpen,
    onFolderCreate,
    onRename
  }: FileTreeElementProps
) => {
  const Icon = file.type === 'folder' ? IconFolder : IconFile;

  return (
    <React.Fragment>
      <li
        className={cx(
          styles.element,
          { [styles.active]: active },
          className
        )}
        onClick={e => {
          file.type === 'folder'
            ? onExpand(file.path)
            : onFileOpen(file.path)
        }}
        style={{
          paddingLeft: (level || 0) * 20
        }}
        title={file.fileName}
      >
        <IconChevron
          className={cx(styles.iconChevron, { [styles.iconChevronFile]: file.type !== 'folder' })}
          direction={expanded ? 'down' : 'right' }
        />
        <Icon className={styles.fileIcon} opened={expanded} />
        <Text
          className={cx(
            styles.fileName,
            { [styles.deleted]: file.deleted }
          )}
        >{file.fileName}</Text>
        {!file.saved && <DotIndicator state='bad' />}
        <div className={cx(styles.buttonsPanel, 'FileTreeElement__btns')}>
          {file.type === 'folder' && (
            <React.Fragment>
              <Button
                className={styles.fileActionBtn}
                intent='plain'
                size='xs'
                icon={IconCreateFolder}
                onClick={e => { e.stopPropagation(); onFolderCreate(file.path); }}
              />
              <Button
                className={cx(styles.fileActionBtn, styles.fileActionBtnMargin)}
                intent='plain'
                size='xs'
                icon={IconCreateFile}
                onClick={e => { e.stopPropagation(); onFileCreate(file.path); }}
              />
            </React.Fragment>
          )}
          <Button
            className={styles.fileActionBtn}
            intent='plain'
            size='xs'
            icon={IconEdit}
            onClick={e => { e.stopPropagation(); onRename(file.path); }}
          />
          <Button
            className={styles.fileActionBtn}
            intent='plain'
            size='xs'
            icon={IconDelete}
            onClick={e => { e.stopPropagation(); onDelete(file.path); }}
          />
        </div>
      </li>
      {expanded && children}
    </React.Fragment>
  );
};
