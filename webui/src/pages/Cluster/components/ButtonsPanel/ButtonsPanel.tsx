/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { ControlsPanel } from '@tarantool.io/ui-kit';

import AuthToggleButton from 'src/components/AuthToggleButton';
import BootstrapButton from 'src/components/BootstrapButton';
// import FailoverButton from 'src/components/FailoverButton';
import { app, cluster } from 'src/models';
// @ts-ignore
// eslint-disable-next-line import/namespace
import { isBootstrapped, isVshardAvailable } from 'src/store/selectors/clusterPage';

import FailoverButton from '../FailoverButton';
import IssuesButton from '../IssuesButton';
import ProbeServerButton from '../ProbeServerButton';

const { compact } = app.utils;
const { isConfigured, isVshardAvailable, isBootstrapped } = cluster.serverList.selectors;

const ButtonsPanel = () => {
  const serverListStore = useStore(cluster.serverList.$serverList);
  const clusterStore = useStore(cluster.serverList.$cluster);

  const authParams = useMemo(() => cluster.serverList.selectors.authParams(clusterStore), [clusterStore]);
  const issues = useMemo(() => cluster.serverList.selectors.issues(serverListStore), [serverListStore]);

  const params = useMemo(() => {
    if (!clusterStore) {
      return undefined;
    }

    const { implements_add_user, implements_check_password, implements_list_users } = authParams;
    return {
      showBootstrap: isConfigured(clusterStore) && isVshardAvailable(clusterStore) && isBootstrapped(clusterStore),
      showToggleAuth: !implements_add_user && !implements_list_users && implements_check_password, // TODO: move to selectors
    };
  }, [clusterStore, authParams]);

  const controls = useMemo(
    () =>
      params
        ? compact([
            <IssuesButton key="IssuesButton" issues={issues} />,
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
    [params]
  );

  if (!controls || controls.length === 0) {
    return null;
  }

  return <ControlsPanel className="meta-test__ButtonsPanel" controls={controls} thin />;
};

export default memo(ButtonsPanel);
