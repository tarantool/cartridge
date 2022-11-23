/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { ControlsPanel } from '@tarantool.io/ui-kit';

import AuthToggleButton from 'src/components/AuthToggleButton';
import { app, cluster } from 'src/models';

import BootstrapButton from '../BootstrapButton';
import FailoverButton from '../FailoverButton';
import IssuesButton from '../IssuesButton';
import ProbeServerButton from '../ProbeServerButton';
import SuggestionsButton from '../SuggestionsButton';

const { compact } = app.utils;
const { isConfigured, isVshardAvailable, isVshardBootstrapped } = cluster.serverList.selectors;

const ButtonsPanel = () => {
  const serverListStore = useStore(cluster.serverList.$serverList);
  const clusterStore = useStore(cluster.serverList.$cluster);
  const suggestions = useStore(cluster.serverList.$suggestions);

  const authParams = useMemo(() => cluster.serverList.selectors.authParams(clusterStore), [clusterStore]);
  const issues = useMemo(() => cluster.serverList.selectors.issues(serverListStore), [serverListStore]);

  const params = useMemo(() => {
    if (!clusterStore) {
      return undefined;
    }

    const { implements_add_user, implements_check_password, implements_list_users } = authParams;
    return {
      showBootstrap:
        isConfigured(clusterStore) && isVshardAvailable(clusterStore) && !isVshardBootstrapped(clusterStore),
      showToggleAuth: !implements_add_user && !implements_list_users && implements_check_password, // TODO: move to selectors
    };
  }, [clusterStore, authParams]);

  const controls = useMemo(
    () =>
      params
        ? compact([
            <IssuesButton key="IssuesButton" issues={issues} />,
            <SuggestionsButton key="SuggestionsButton" suggestions={suggestions} />,
            <ProbeServerButton key="ProbeServerButton" />,
            params.showToggleAuth && (
              <AuthToggleButton
                key="AuthToggleButton"
                implements_check_password={!!authParams.implements_check_password}
              />
            ),
            <FailoverButton key="FailoverButton" />,
            params.showBootstrap && <BootstrapButton key="BootstrapButton" />,
          ])
        : undefined,
    [issues, suggestions, params, authParams]
  );

  if ((controls?.length ?? 0) === 0) {
    return null;
  }

  return <ControlsPanel className="meta-test__ButtonsPanel" controls={controls} thin />;
};

export default memo(ButtonsPanel);
