import React from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
import { Button, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import Panel from '../Panel';
import AdvertiseURISuggestionModal from './components/AdvertiseURISuggestionModal';
import DisableServersSuggestionModal from './components/DisableServersSuggestionModal';
import ForceApplySuggestionModal from './components/ForceApplySuggestionModal';
import RestartReplicationsSuggestionModal from './components/RestartReplicationsSuggestionModal';

import { styles } from './ClusterSuggestionsPanel.styles';

const {
  $panelsVisibility,
  advertiseURIDetailsClick,
  disableServersDetailsClick,
  forceApplyConfDetailsClick,
  restartReplicationsDetailsClick,
} = cluster.suggestions;

const META_TEST_PANEL_CLASS_NAME = 'meta-test__ClusterSuggestionsPanel';

const ClusterSuggestionsPanel = () => {
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

export default ClusterSuggestionsPanel;
