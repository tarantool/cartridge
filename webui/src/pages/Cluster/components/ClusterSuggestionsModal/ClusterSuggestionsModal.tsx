/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
// @ts-ignore
import { Button, Modal, Text } from '@tarantool.io/ui-kit';

import type { Suggestion } from 'src/models';

import { styles } from './ClusterSuggestionsModal.styles';

export interface ClusterSuggestionsModalProps {
  suggestions: Suggestion[];
  onClose: () => void;
  visible: boolean;
}

export const ClusterSuggestionsModal = ({ suggestions, visible, onClose }: ClusterSuggestionsModalProps) => {
  const suggestionsNodes = React.useMemo((): React.ReactNode[] => {
    const flatten = Array.from(
      suggestions
        .reduce((acc: Map<string, { field: string; space: string; compressed: number }>, item) => {
          item.meta.fields.forEach((field) => {
            acc.set(`${item.meta.spaceName}~${field.name}`, {
              space: item.meta.spaceName,
              field: field.name,
              compressed: field.compressionPercentage,
            });
          });

          return acc;
        }, new Map())
        .values()
    );

    return flatten.map(({ field, space, compressed }, index) => (
      <Text key={index}>
        {'Field '}
        <strong>{field}</strong>
        {' in space '}
        <strong>{space}</strong>
        {' can be compressed down to '}
        <strong>{compressed}%</strong>
      </Text>
    ));
  }, [suggestions]);

  return (
    <Modal
      className="meta-test__ClusterSuggestionsModal"
      visible={visible}
      onClose={onClose}
      title={
        <div>
          Suggestions: <span className={styles.title}>{suggestionsNodes.length}</span>
        </div>
      }
      footerControls={[
        <Button key="Close" className="meta-test__closeClusterSuggestionsModal" onClick={onClose} size="l">
          Close
        </Button>,
      ]}
    >
      <div className={styles.list}>
        {suggestionsNodes.map((node, index) => (
          <div key={index} className={styles.suggestionContent}>
            {node}
          </div>
        ))}
      </div>
    </Modal>
  );
};

export default ClusterSuggestionsModal;
