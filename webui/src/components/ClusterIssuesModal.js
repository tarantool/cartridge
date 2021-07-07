// @flow
import * as React from 'react';
import { css, cx } from '@emotion/css';
import {
  Button,
  Modal,
  Text,
  colors
} from '@tarantool.io/ui-kit';
import type { Issue } from 'src/generated/graphql-typing';

const styles = {
  list: css`
    padding: 0;
  `,
  title: css`
    color: ${colors.dark40};
  `,
  issueContent: css`
    padding-bottom: 10px;
    margin-bottom: 10px;
    border-bottom: 1px solid ${colors.intentBase};
  `,
  titleCritical: css`
    color: ${colors.intentWarningAccent};
  `
};

type ClusterIssuesModalProps = {
  issues: Issue[],
  onClose: (e: MouseEvent) => void,
  visible: boolean,
}

export const ClusterIssuesModal = (
  { issues, visible, onClose }: ClusterIssuesModalProps
) => (
  <Modal
    className='meta-test__ClusterIssuesModal'
    visible={visible}
    onClose={onClose}
    title={<div>Issues: <span className={styles.title}>{issues.length}</span></div>}
    footerControls={[
      <Button
        className='meta-test__closeClusterIssuesModal'
        onClick={onClose}
        size='l'
      >
        Close
      </Button>
    ]}
  >
    <div className={styles.list}>
      {issues.map(({ level, message }) => (
        <div className={styles.issueContent}>
          <Text className={cx({ [styles.titleCritical]: level === 'critical' })} variant='h5'>{level}</Text>
          <Text>{message}</Text>
        </div>
      ))}
    </div>
  </Modal>
);
