/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { cx } from '@emotion/css';
import { useEvent, useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { styles } from './ClusterSuggestionsModal.styles';

export const ClusterSuggestionsModal = () => {
  const modal = useStore(cluster.serverSuggestions.$serverSuggestionsModal);
  const handleClose = useEvent(cluster.serverSuggestions.serverSuggestionsModalCloseEvent);
  const handleContinue = useEvent(cluster.serverSuggestions.serverSuggestionsEvent);

  const suggestionsNodes = React.useMemo((): React.ReactNode[] => {
    if (modal.state !== 'content' || !modal.data) {
      return [];
    }

    const flatten = Array.from(
      modal.data
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
  }, [modal.data, modal.state]);

  const footerControls = React.useMemo(() => {
    if (modal.state === 'initial' || modal.state === 'pending') {
      return [
        <Button key="Cancel" className="meta-test__cancelClusterSuggestionsModal" onClick={handleClose} size="l">
          Cancel
        </Button>,
        <Button
          key="Continue"
          className={cx('meta-test__continueClusterSuggestionsModal', styles.btn)}
          loading={modal.state === 'pending'}
          onClick={modal.state === 'pending' ? undefined : handleContinue}
          intent="primary"
          size="l"
        >
          Continue
        </Button>,
      ];
    }

    return [
      <Button key="Close" className="meta-test__cancelClusterSuggestionsModal" onClick={handleClose} size="l">
        Close
      </Button>,
    ];
  }, [handleClose, handleContinue, modal.state]);

  let content: React.ReactNode = null;

  switch (modal.state) {
    case 'initial':
    case 'pending': {
      content = (
        <div className={styles.content}>
          <Text>
            Next, you can see the amount of space that can be freed up in the cluster by compressing some of the fields.
            The algorithm calculates it based on the cluster data. The procedure might temporarily switch some nodes to
            the <b>Unreachable</b> state, from a few seconds to several minutes. Also, the procedure might create an
            auto-incident in your alert system. To prevent this, it is recommended to run the procedure during scheduled
            maintenance time (or <b>during the change window</b>).
          </Text>
        </div>
      );
      break;
    }
    case 'error': {
      content = (
        <div className={styles.content}>
          <Alert type="error">{modal.error}</Alert>
        </div>
      );
      break;
    }
    case 'content': {
      content = (
        <div className={styles.content}>
          {suggestionsNodes.length === 0 ? <Text>No suggestions</Text> : null}
          {suggestionsNodes.map((node, index) => (
            <div key={index} className={styles.suggestion}>
              {node}
            </div>
          ))}
        </div>
      );
      break;
    }
  }

  return (
    <Modal
      className="meta-test__ClusterSuggestionsModal"
      visible={modal.visible}
      onClose={handleClose}
      title={modal.state === 'initial' || modal.state === 'pending' ? 'Warning' : 'Suggestions'}
      footerControls={footerControls}
    >
      {content}
    </Modal>
  );
};

export default ClusterSuggestionsModal;
