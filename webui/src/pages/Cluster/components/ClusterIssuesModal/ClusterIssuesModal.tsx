/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { cx } from '@emotion/css';
// @ts-ignore
import { Button, Modal, Text } from '@tarantool.io/ui-kit';

import type { ServerListClusterIssue } from 'src/models';

import { styles } from './ClusterIssuesModal.styles';

export interface ClusterIssuesModalProps {
  issues: ServerListClusterIssue[];
  onClose: () => void;
  visible: boolean;
}

export const ClusterIssuesModal = ({ issues, visible, onClose }: ClusterIssuesModalProps) => (
  <Modal
    className="meta-test__ClusterIssuesModal"
    visible={visible}
    onClose={onClose}
    title={
      <div>
        Issues: <span className={styles.title}>{issues.length}</span>
      </div>
    }
    footerControls={[
      <Button key="Close" className="meta-test__closeClusterIssuesModal" onClick={onClose} size="l">
        Close
      </Button>,
    ]}
  >
    <div className={styles.list}>
      {issues.map(({ level, message }, index) => (
        <div key={index} className={styles.issueContent}>
          <Text className={cx({ [styles.titleCritical]: level === 'critical' })} variant="h5">
            {level}
          </Text>
          <Text>{message}</Text>
        </div>
      ))}
    </div>
  </Modal>
);

export default ClusterIssuesModal;
