// @flow
import React from 'react';
import { css, cx } from 'emotion'
import { useStore } from 'effector-react';
import { Button, Text } from '@tarantool.io/ui-kit';
import {
  $panelsVisibility,
  advertiseURIDetailsClick,
  disableServersDetailsClick
} from 'src/store/effector/clusterSuggestions';
import { Panel } from './Panel';
import { AdvertiseURISuggestionModal } from './AdvertiseURISuggestionModal';
import DisableServersSuggestionModal from './DisableServersSuggestionModal';

const styles = {
  wrap: css`
    margin-bottom: 22px;
  `,
  panel: css`
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
  `,
  heading: css`
    margin-bottom: 6px;
  `
};

export const ClusterSuggestionsPanel = () => {
  const { advertiseURI, disableServers } = useStore($panelsVisibility);

  return (
    <div className={styles.wrap}>
      {advertiseURI
        ? (
          <Panel className={cx(styles.panel, 'meta-test__ClusterSuggestionsPanel')}>
            <div>
              <Text className={styles.heading} variant='h5'>Change advertise URI</Text>
              <Text>
                Seems that some instances were restarted with a different advertise_uri.
                Update configuration to fix it.
              </Text>
            </div>
            <Button text='Review changes' onClick={advertiseURIDetailsClick} intent='primary' size='l' />
            <AdvertiseURISuggestionModal />
          </Panel>
        )
        : null}
      {disableServers
        ? (
          <Panel className={cx(styles.panel, 'meta-test__ClusterSuggestionsPanel')}>
            <div>
              <Text className={styles.heading} variant='h5'>Disable instances</Text>
              <Text>
                Some instances are malfunctioning and impede editing clusterwide configuration.
                Disable them temporarily if you want to operate topology.
              </Text>
            </div>
            <Button text='Review' onClick={disableServersDetailsClick} intent='primary' size='l' />
            <DisableServersSuggestionModal />
          </Panel>
        )
        : null}
    </div>
  );
};
