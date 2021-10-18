/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
/* prettier-ignore */
// @ts-ignore
import { Button, ControlsPanel, DropdownDivider, DropdownItem, IconChevronDown, Modal, Spin, Tabbed, Text, UriLabel, withPopover } from '@tarantool.io/ui-kit';

import { HealthStatus } from 'src/components/HealthStatus';
import { app, cluster } from 'src/models';

import ServerDropdown from '../ServerDropdown';
import IssuesTab from './components/IssuesTab';
import ModalTitle from './components/ModalTitle';
import StatTab from './components/StatTab';
import VshardRouterTab from './components/VshardRouterTab';

import { styles } from './ServerDetailsModal.styles';

const { upFirst, stopPropagation, isLike, compact } = app.utils;
const { $cluster, $serverList, selectors, promoteServerToLeaderEvent } = cluster.serverList;
const { zoneAddModalOpenEvent, $zoneAddModal, setServerZoneEvent } = cluster.zones;
const { serverDetailsModalClosedEvent, $serverDetails, $selectedServerDetailsUuid } = cluster.serverDetails;

const PopoverButton = withPopover(Button);

const ServerDetailsModal = () => {
  const clusterStore = useStore($cluster);
  const serverList = useStore($serverList);
  const serverDetails = useStore($serverDetails);
  const uuid = useStore($selectedServerDetailsUuid);

  const { pending } = useStore($zoneAddModal);

  const [clusterSelfUri, failoverParamsMode] = useMemo(
    () => [selectors.clusterSelfUri(clusterStore), selectors.failoverParamsMode(clusterStore)],
    [clusterStore]
  );

  const zones = useMemo(() => selectors.zones(serverList), [serverList]);

  const [server, issues] = useMemo(
    () => [selectors.serverGetByUuid(serverList, uuid), selectors.issuesFilteredByInstanceUuid(serverList, uuid)],
    [uuid, serverList]
  );

  const replicaset = useMemo(
    () => selectors.replicasetGetByUuid(serverList, server?.replicaset?.uuid),
    [serverList, server?.replicaset?.uuid]
  );

  const [isMaster, isActiveMaster] = useMemo(
    () => [selectors.isMaster(replicaset, server?.uuid), selectors.isActiveMaster(replicaset, server?.uuid)],
    [replicaset, server?.uuid]
  );

  const showFailoverPromote = (replicaset?.servers.length ?? 0) > 1 && failoverParamsMode === 'stateful';

  const handleClosePopup = useCallback(() => {
    serverDetailsModalClosedEvent();
  }, []);

  const handleZoneSelect = useCallback(
    (_, pass: string) => {
      if (server && pass) {
        setServerZoneEvent({
          uuid: server.uuid,
          zone: server.zone === pass ? '' : pass,
        });
      }
    },
    [server]
  );

  const handleAddZone = useCallback(
    (_, pass: unknown) => {
      if (server && isLike<string>(pass)) {
        zoneAddModalOpenEvent({ uuid: pass });
      }
    },
    [server]
  );

  const handlePromoteLeader = useCallback(() => {
    if (showFailoverPromote && server && replicaset) {
      promoteServerToLeaderEvent({
        instanceUuid: server.uuid,
        replicasetUuid: replicaset.uuid,
        force: isActiveMaster,
      });
      handleClosePopup();
    }
  }, [server, replicaset, isActiveMaster, showFailoverPromote]);

  const controls = useMemo(
    () =>
      compact([
        <PopoverButton
          key={0}
          intent="secondary"
          text={server?.zone ? `Zone ${server.zone}` : 'Select zone'}
          size="l"
          iconRight={IconChevronDown}
          loading={pending}
          popoverClassName={styles.popover}
          popoverContent={
            <>
              {zones.map((zoneName) => (
                <DropdownItem
                  key={zoneName}
                  onClick={(_) => handleZoneSelect(_, zoneName)}
                  pass={zoneName}
                  className={cx('meta-test__ZoneListItem', styles.zone, {
                    [styles.activeZone]: server?.zone === zoneName,
                  })}
                >
                  {zoneName}
                </DropdownItem>
              ))}
              {zones.length > 0 ? (
                <DropdownDivider />
              ) : (
                <Text className={styles.noZoneLabel} variant="p" tag="div" onClick={stopPropagation}>
                  {'You have no any zone,\nplease add one.'}
                </Text>
              )}
              <Button
                className={styles.zoneAddBtn}
                size="l"
                intent="secondary"
                text="Add new zone"
                onClick={handleAddZone}
                pass={server?.uuid}
              />
            </>
          }
        />,
        ...(showFailoverPromote && server && replicaset
          ? [
              <Button
                key={1}
                intent="secondary"
                text={isActiveMaster ? 'Force promote' : 'Promote'}
                size="l"
                onClick={handlePromoteLeader}
              />,
            ]
          : []),
        server && <ServerDropdown key={1} intent="secondary" size="l" uuid={server.uuid} />,
      ]),
    [server, replicaset, isActiveMaster, pending, showFailoverPromote]
  );

  const tabs = useMemo(
    () =>
      (
        [
          'general',
          'cartridge',
          'replication',
          'storage',
          'network',
          'membership',
          'vshard_router',
          'vshard_storage',
          'issues',
        ] as const
      ).map((section) => {
        switch (section) {
          case 'vshard_router':
            return {
              label: 'Vshard-Router',
              content: <VshardRouterTab />,
            };
          case 'issues':
            return {
              label: `Issues ${issues.length}`,
              content: <IssuesTab issues={issues} />,
            };
          default:
            return {
              label: section === 'vshard_storage' ? 'Vshard-Storage' : upFirst(section),
              content: <StatTab sectionName={section} />,
            };
        }
      }),
    [issues]
  );

  if (!server) {
    return null;
  }

  return (
    <Modal
      className={cx('meta-test__ServerDetailsModal', styles.modal)}
      visible
      title={
        <ModalTitle
          isMaster={isMaster || isActiveMaster}
          disabled={server.disabled}
          alias={server.alias}
          uuid={server.uuid}
          status={server.status}
          ro={selectors.serverRo(server)}
        />
      }
      footerControls={[<Button key="Close" onClick={handleClosePopup} text="Close" size="l" />]}
      onClose={handleClosePopup}
      wide
    >
      <Spin enable={!serverDetails}>
        <div className={styles.firstLine}>
          <div>
            <UriLabel
              weAreHere={clusterSelfUri && server.uri === clusterSelfUri}
              className={clusterSelfUri && server.uri === clusterSelfUri && 'meta-test__youAreHereIcon'}
              title="URI"
              uri={server.uri}
            />
            <HealthStatus status={server.status} message={server.message} />
          </div>
          <ControlsPanel controls={controls} thin />
        </div>
        <Tabbed tabs={tabs} />
      </Spin>
    </Modal>
  );
};

export default ServerDetailsModal;
