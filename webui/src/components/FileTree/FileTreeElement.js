// @flow
import * as React from 'react';
import { cx } from 'emotion';
import {
  Button,
  DotIndicator,
  IconBucket,
  IconChevron,
  IconCreateFolder,
  IconCreateFile,
  IconEdit,
  IconFile,
  IconFolder,
  Text
} from '@tarantool.io/ui-kit';
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import { styles } from './styles';

type FileTreeElementProps = {
  active?: boolean,
  children?: React.Node,
  className?: string,
  expanded?: boolean,
  file: TreeFileItem,
  level?: number,
  onDelete: (id: string) => void,
  onExpand: (id: string) => void,
  onFileCreate: (file: TreeFileItem) => void,
  onFileOpen: (id: string) => void,
  onFolderCreate: (file: TreeFileItem) => void,
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
          styles.row,
          { [styles.active]: active },
          className
        )}
        onClick={e => {
          file.type === 'folder'
            ? onExpand(file.fileId)
            : onFileOpen(file.fileId)
        }}
        style={{
          paddingLeft: (level || 0) * 20
        }}
        title={file.fileName}
      >
        <IconChevron
          className={cx(
            styles.iconChevron,
            { [styles.iconChevronHidden]: !file.items || !file.items.length }
          )}
          direction={expanded ? 'down' : 'right' }
        />
        <Icon className={styles.fileIcon} opened={expanded} />
        <Text className={styles.fileName}>{file.fileName}</Text>
        {(!file.saved || (!!file.initialPath && file.initialPath !== file.path)) && (
          <DotIndicator state='bad' />
        )}
        <div className={cx(styles.buttonsPanel, 'FileTreeElement__btns')}>
          {file.type === 'folder' && (
            <React.Fragment>
              <Button
                className={cx(styles.fileActionBtn, 'meta-test__createFolderInTreeBtn')}
                intent='secondary'
                size='s'
                icon={IconCreateFolder}
                onClick={e => { e.stopPropagation(); onFolderCreate(file); }}
                title='Create folder'
              />
              <Button
                className={cx(styles.fileActionBtn, 'meta-test__createFileInTreeBtn')}
                intent='secondary'
                size='s'
                icon={IconCreateFile}
                onClick={e => { e.stopPropagation(); onFileCreate(file); }}
                title='Create file'
              />
            </React.Fragment>
          )}
          <Button
            className={cx(styles.fileActionBtn, 'meta-test__editFolderInTreeBtn')}
            intent='secondary'
            size='s'
            icon={IconEdit}
            onClick={e => { e.stopPropagation(); onRename(file.path); }}
            title='Rename'
          />
          <Button
            className={cx(styles.fileActionBtn, 'meta-test__deleteFolderInTreeBtn')}
            intent='secondary'
            size='s'
            icon={IconBucket}
            onClick={e => { e.stopPropagation(); onDelete(file.path); }}
            title='Delete'
          />
        </div>
      </li>
      {expanded && children}
    </React.Fragment>
  );
};
