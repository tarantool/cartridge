// @flow
import React from 'react';
import { css, cx } from 'emotion'
import { useStore } from 'effector-react';
import { Button, Text } from '@tarantool.io/ui-kit';
import {
  $advertisePanelVisible,
  detailsClick
} from 'src/store/effector/clusterSuggestions';
import { Panel } from './Panel';
import { ClusterSuggestionsModal } from './ClusterSuggestionsModal';

const styles = {
  panel: css`
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 42px;
  `,
  heading: css`
    margin-bottom: 6px;
  `
};

export const ClusterSuggestionsPanel = () => {
  const visible = useStore($advertisePanelVisible);

  if (!visible)
    return null;

  return (
    <Panel className={cx(styles.panel, 'meta-test__ClusterSuggestionsPanel')}>
      <div>
        <Text className={styles.heading} variant='h5'>Advertise URI change</Text>
        <Text>
          Seems that some instances were restarted with a different advertise_uri.
          Update configuration to fix it.
        </Text>
      </div>
      <Button text='Review changes' onClick={detailsClick} intent='primary' size='l' />
      <ClusterSuggestionsModal />
    </Panel>
  );
};
