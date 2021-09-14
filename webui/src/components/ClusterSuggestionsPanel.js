// @flow
import React from 'react';
import { css, cx } from '@emotion/css';
import { useStore } from 'effector-react';
import { Button, Text } from '@tarantool.io/ui-kit';

import {
  $panelsVisibility,
  advertiseURIDetailsClick,
  disableServersDetailsClick,
  forceApplyConfDetailsClick,
  restartReplicationsDetailsClick,
} from 'src/store/effector/clusterSuggestions';

import { AdvertiseURISuggestionModal } from './AdvertiseURISuggestionModal';
import DisableServersSuggestionModal from './DisableServersSuggestionModal';
import ForceApplySuggestionModal from './ForceApplySuggestionModal';
import { Panel } from './Panel';
import RestartReplicationsSuggestionModal from './RestartReplicationsSuggestionModal';

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
  `,
};

const META_TEST_PANEL_CLASS_NAME = 'meta-test__ClusterSuggestionsPanel';

export const ClusterSuggestionsPanel = () => {
  const { advertiseURI, disableServers, forceApply, restartReplication } = useStore($panelsVisibility);

  return (
    <div className={styles.wrap}>
      {advertiseURI ? (
        <Panel className={cx(styles.panel, META_TEST_PANEL_CLASS_NAME)}>
          <div>
            <Text className={styles.heading} variant="h5">
              Change advertise URI
            </Text>
            <Text>
              Seems that some instances were restarted with a different advertise_uri. Update configuration to fix it.
            </Text>
          </div>
          <Button text="Review changes" onClick={advertiseURIDetailsClick} intent="primary" size="l" />
          <AdvertiseURISuggestionModal />
        </Panel>
      ) : null}
      {disableServers ? (
        <Panel className={cx(styles.panel, META_TEST_PANEL_CLASS_NAME)}>
          <div>
            <Text className={styles.heading} variant="h5">
              Disable instances
            </Text>
            <Text>
              Some instances are malfunctioning and impede editing clusterwide configuration. Disable them temporarily
              if you want to operate topology.
            </Text>
          </div>
          <Button text="Review" onClick={disableServersDetailsClick} intent="primary" size="l" />
          <DisableServersSuggestionModal />
        </Panel>
      ) : null}
      {forceApply ? (
        <Panel className={cx(styles.panel, 'meta-test__ClusterSuggestionsPanel')}>
          <div>
            <Text className={styles.heading} variant="h5">
              Force apply configuration
            </Text>
            <Text>Some instances are misconfigured. You can heal it by reapplying configuration forcefully.</Text>
          </div>
          <Button text="Review" onClick={forceApplyConfDetailsClick} intent="primary" size="l" />
          <ForceApplySuggestionModal />
        </Panel>
      ) : null}
      {restartReplication ? (
        <Panel className={cx(styles.panel, META_TEST_PANEL_CLASS_NAME)}>
          <div>
            <Text className={styles.heading} variant="h5">
              Restart replication
            </Text>
            <Text>{"The replication isn't all right. Restart it, maybe it helps."}</Text>
          </div>
          <Button text="Review" onClick={restartReplicationsDetailsClick} intent="primary" size="l" />
          <RestartReplicationsSuggestionModal />
        </Panel>
      ) : null}
    </div>
  );
};
