// @flow
import * as React from 'react';
import {
  Button,
  Modal,
  Text
} from '@tarantool.io/ui-kit';
import type { Issue } from 'src/generated/graphql-typing';

type ClusterIssuesModalProps = {
  issues: Issue[],
  onClose: (e: MouseEvent) => void,
  visible: boolean,
}

export const ClusterIssuesModal = ({ issues, visible, onClose }: ClusterIssuesModalProps) => (
  <Modal
    className='meta-test__ClusterIssuesModal'
    visible={visible}
    onClose={onClose}
    title={`Issues: ${issues.length}`}
    footerControls={[
      <Button className='meta-test__closeClusterIssuesModal' onClick={onClose}>Close </Button>
    ]}
  >
    <ul>
      {issues.map(({ level, message }) => (
        <Text tag='li'><b>{level}:</b> {message}</Text>
      ))}
    </ul>
  </Modal>
);
