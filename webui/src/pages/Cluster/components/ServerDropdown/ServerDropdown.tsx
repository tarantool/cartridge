/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { memo, useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
// @ts-ignore
import { Button, Dropdown, DropdownItem, IconMore } from '@tarantool.io/ui-kit';
import type { ButtonProps } from '@tarantool.io/ui-kit';

import { app, cluster } from 'src/models';

import { styles } from './ServerDropdown.styles';

const { compact } = app.utils;
const { $serverList, promoteServerToLeaderEvent, disableOrEnableServerEvent, setElectableServerEvent, selectors } =
  cluster.serverList;
const { serverDetailsModalOpenedEvent } = cluster.serverDetails;
const { serverExpelModalOpenEvent } = cluster.serverExpel;
const { serverAddLabelModalOpenEvent } = cluster.addLabels;

export interface ServerDropdownProps {
  className?: string;
  uuid: string;
  showServerDetails?: boolean;
  showFailoverPromote?: boolean;
  intent?: ButtonProps['intent'];
  size?: ButtonProps['size'];
}

const ServerDropdown = ({
  className,
  showServerDetails,
  showFailoverPromote,
  intent,
  size,
  uuid,
}: ServerDropdownProps) => {
  const serverList = useStore($serverList);

  const server = useMemo(() => selectors.serverGetByUuid(serverList, uuid), [uuid, serverList]);

  const replicaset = useMemo(
    () => selectors.replicasetGetByUuid(serverList, server?.replicaset?.uuid),
    [serverList, server?.replicaset?.uuid]
  );

  const isActiveMaster = useMemo(() => selectors.isActiveMaster(replicaset, server?.uuid), [replicaset, server?.uuid]);

  const handleServerDetails = useCallback(() => {
    if (server?.uuid) {
      serverDetailsModalOpenedEvent({ uuid: server.uuid });
    }
  }, [server?.uuid]);

  const handleAddLabelForServer = useCallback(() => {
    if (server?.uuid) {
      serverAddLabelModalOpenEvent({ uuid: server.uuid });
    }
  }, [server?.uuid]);

  const handlePromoteLeader = useCallback(() => {
    if (server?.uuid && replicaset?.uuid) {
      promoteServerToLeaderEvent({
        instanceUuid: server.uuid,
        replicasetUuid: replicaset.uuid,
        force: isActiveMaster,
      });
    }
  }, [server?.uuid, replicaset?.uuid, isActiveMaster]);

  const handleSetElectableServer = useCallback(() => {
    if (server?.uuid) {
      setElectableServerEvent({
        uuid: server.uuid,
        electable: server?.electable === false,
      });
    }
  }, [server?.uuid, server?.electable]);

  const handleEnableOrDisableServer = useCallback(() => {
    if (server?.uuid) {
      disableOrEnableServerEvent({
        uuid: server.uuid,
        disable: !server.disabled,
      });
    }
  }, [server?.uuid, server?.disabled]);

  const handleShowExpelModal = useCallback(() => {
    if (server?.uri) {
      serverExpelModalOpenEvent({
        uri: server.uri,
      });
    }
  }, [server?.uri]);

  const items = useMemo(
    () =>
      compact([
        showServerDetails && server && (
          <DropdownItem key="handleServerDetails" onClick={handleServerDetails}>
            Server details
          </DropdownItem>
        ),
        showFailoverPromote && server && replicaset && (
          <DropdownItem key="handlePromoteLeader" onClick={handlePromoteLeader}>
            {isActiveMaster ? 'Force promote a leader' : 'Promote a leader'}
          </DropdownItem>
        ),
        <DropdownItem key="handleSetElectableServer" onClick={handleSetElectableServer}>
          {server?.electable === false ? 'Set as electable' : 'Set as non-electable'}
        </DropdownItem>,
        <DropdownItem key="handleEnableDisableServer" onClick={handleEnableOrDisableServer}>
          {server?.disabled ? 'Enable server' : 'Disable server'}
        </DropdownItem>,
        <DropdownItem key="handleAddLabelsServer" onClick={handleAddLabelForServer}>
          Server labels
        </DropdownItem>,
        <DropdownItem
          key="handleShowExpelModal"
          className={styles.showExpelModalDropdown}
          onClick={handleShowExpelModal}
        >
          Expel server
        </DropdownItem>,
      ]),
    [
      showServerDetails,
      server,
      handleServerDetails,
      showFailoverPromote,
      replicaset,
      handlePromoteLeader,
      isActiveMaster,
      handleSetElectableServer,
      handleEnableOrDisableServer,
      handleAddLabelForServer,
      handleShowExpelModal,
    ]
  );

  if (items.length === 0) {
    return null;
  }

  return (
    <Dropdown
      items={items}
      className={cx(className, 'meta-test__ReplicasetServerListItem__dropdownBtn')}
      popoverClassName="meta-test__ReplicasetServerListItem__dropdown"
    >
      <Button icon={IconMore} size={size || 's'} intent={intent || 'plain'} />
    </Dropdown>
  );
};

export default memo(ServerDropdown);
