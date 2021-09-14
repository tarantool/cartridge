// @flow
import React from 'react';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import { css, cx } from '@emotion/css';
import { filter, identity, uniq } from 'ramda';
import {
  Button,
  ControlsPanel,
  DropdownDivider,
  DropdownItem,
  IconChevronDown,
  Modal,
  Tabbed,
  Text,
  UriLabel,
  colors,
  withPopover,
} from '@tarantool.io/ui-kit';

import type { Issue, Replicaset } from 'src/generated/graphql-typing';
import { pageDidMount, resetPageState } from 'src/store/actions/clusterInstancePage.actions';
import { failoverPromoteLeader } from 'src/store/actions/clusterPage.actions';
import { chooseZoneFail, setInstanceZoneFx, zoneAddModalOpen } from 'src/store/effector/clusterZones';
import store from 'src/store/instance';

import { graphqlErrorNotification } from '../../misc/graphqlErrorNotification';
import { HealthStatus } from '../HealthStatus';
import { Label } from '../Label';
import { LeaderLabel } from '../LeaderLabel';
import { ServerDropdown } from '../ServerDropdown';
import { ServerDetailsModalIssues } from './ServerDetailsModalIssues';
import ServerDetailsModalStatTab from './ServerDetailsModalStatTab';
import ServerDetailsModalVshardRouterTab from './ServerDetailsModalVshardRouterTab';

const styles = {
  firstLine: css`
    display: flex;
    justify-content: space-between;
    margin-bottom: 21px;
  `,
  modal: css`
    max-width: 1050px;
  `,
  flag: css`
    margin-left: 20px;
    margin-bottom: 3px;
    vertical-align: middle;
  `,
  flagMarginBetween: css`
    margin-left: 10px;
  `,
  headingWidthLimit: css`
    max-width: 780px;
    display: inline-block;
    overflow: hidden;
    text-overflow: ellipsis;
    vertical-align: bottom;
  `,
  popover: css`
    padding: 8px 0;
  `,
  noZoneLabel: css`
    display: block;
    padding: 12px 18px 5px;
    color: ${colors.dark40};
    white-space: pre-wrap;
  `,
  zoneAddBtn: css`
    margin: 12px 20px;
  `,
  zone: css`
    position: relative;
    padding-left: 32px;
  `,
  activeZone: css`
    &:before {
      position: absolute;
      display: block;
      top: 50%;
      transform: translateY(-50%);
      content: '';
      height: 6px;
      width: 6px;
      border-radius: 50%;
      margin-left: -16px;
      background-color: ${colors.intentPrimary};
    }
  `,
};

const PopoverButton = withPopover(Button);

chooseZoneFail.watch((data) => {
  graphqlErrorNotification(data, 'Zone change error');
});

type ServerDetailsModalProps = {
  history: History,
  pageDidMount: ({ instanceUUID: string }) => void,
  resetPageState: () => void,
  alias: string,
  disabled: boolean,
  issues: Issue[],
  failoverMode: string,
  selfURI?: string,
  instanceUUID: string,
  replicaset?: Replicaset,
  labels: { name: string, value: string }[],
  message?: string,
  masterUUID: string,
  activeMasterUUID?: string,
  status: string,
  uri: string,
  match: { url: string },
  history: History,
  ro?: boolean,
  zone: ?string,
  zoneList: string[],
};

type ServerDetailsModalState = {
  selectedTab: ?string,
};

class ServerDetailsModal extends React.Component<ServerDetailsModalProps, ServerDetailsModalState> {
  state = {
    selectedTab: null,
  };

  static tabsOrder = ['general', 'cartridge', 'replication', 'storage', 'network', 'membership'];

  componentDidMount() {
    this.props.pageDidMount({
      instanceUUID: this.props.instanceUUID,
    });
  }

  componentWillUnmount() {
    this.props.resetPageState();
  }

  close = () => {
    this.props.history.push('/cluster/dashboard');
  };

  render() {
    const {
      alias,
      disabled,
      issues,
      history,
      replicaset = {},
      instanceUUID,
      selfURI,
      activeMasterUUID,
      failoverMode,
      masterUUID,
      message,
      status,
      uri,
      ro,
      zone,
      zoneList,
    } = this.props;

    const activeMaster = instanceUUID === activeMasterUUID;
    const master = instanceUUID === masterUUID;
    const showFailoverPromote = replicaset.servers && replicaset.servers.length > 1 && failoverMode === 'stateful';

    return (
      <Modal
        className={cx('meta-test__ServerDetailsModal', styles.modal)}
        title={
          <>
            <span className={styles.headingWidthLimit}>{alias || instanceUUID}</span>
            {(master || activeMaster) && (
              <LeaderLabel
                className={styles.flag}
                state={status !== 'healthy' ? 'bad' : ro === false ? 'good' : 'warning'}
              />
            )}
            {disabled && (
              <Label className={cx(styles.flag, { [styles.flagMarginBetween]: master || activeMaster })}>
                Disabled
              </Label>
            )}
          </>
        }
        footerControls={[<Button key="Close" onClick={this.close} text="Close" size="l" />]}
        visible={true}
        onClose={this.close}
        wide
      >
        <div className={styles.firstLine}>
          <div>
            <UriLabel
              weAreHere={selfURI && uri === selfURI}
              className={selfURI && uri === selfURI && 'meta-test__youAreHereIcon'}
              title="URI"
              uri={uri}
            />
            <HealthStatus status={status} message={message} />
          </div>
          <ControlsPanel
            controls={[
              <PopoverButton
                key={0}
                intent="secondary"
                text={zone ? 'Zone ' + zone : 'Select zone'}
                size="l"
                iconRight={IconChevronDown}
                popoverClassName={styles.popover}
                // TODO: add loading state while applying
                popoverContent={
                  <>
                    {zoneList.map((zoneName) => (
                      <DropdownItem
                        key={zoneName}
                        onClick={() =>
                          setInstanceZoneFx({ uuid: instanceUUID, zone: zone === zoneName ? '' : zoneName })
                        }
                        className={cx('meta-test__ZoneListItem', styles.zone, {
                          [styles.activeZone]: zone === zoneName,
                        })}
                      >
                        {zoneName}
                      </DropdownItem>
                    ))}
                    {zoneList.length ? (
                      <DropdownDivider />
                    ) : (
                      <Text className={styles.noZoneLabel} variant="p" tag="div" onClick={(e) => e.stopPropagation()}>
                        {'You have no any zone,\nplease add one.'}
                      </Text>
                    )}
                    <Button
                      className={styles.zoneAddBtn}
                      size="l"
                      intent="secondary"
                      text="Add new zone"
                      onClick={() => zoneAddModalOpen(instanceUUID)}
                    />
                  </>
                }
              />,
              ...(showFailoverPromote && replicaset
                ? [
                    <Button
                      key={1}
                      intent="secondary"
                      text={activeMaster ? 'Force promote' : 'Promote'}
                      size="l"
                      onClick={() => {
                        store.dispatch(failoverPromoteLeader(replicaset.uuid, instanceUUID, activeMaster));
                        this.close();
                      }}
                    />,
                  ]
                : []),
              replicaset && (
                <ServerDropdown
                  key={2}
                  disabled={disabled}
                  intent="secondary"
                  activeMaster={activeMaster}
                  replicasetUUID={replicaset.uuid}
                  uri={uri}
                  history={history}
                  uuid={instanceUUID}
                  size="l"
                />
              ),
            ].filter(Boolean)}
            thin
          />
        </div>
        <Tabbed
          tabs={[
            ...filter(identity, ServerDetailsModal.tabsOrder).map((section) => ({
              label: section[0].toUpperCase() + section.substring(1),
              content: <ServerDetailsModalStatTab sectionName={section} />,
            })),
            {
              label: 'Vshard-Router',
              content: <ServerDetailsModalVshardRouterTab sectionName={'vshard_router'} />,
            },
            {
              label: 'Vshard-Storage',
              content: <ServerDetailsModalStatTab sectionName={'vshard_storage'} />,
            },
            {
              label: 'Issues ' + issues.length,
              content: <ServerDetailsModalIssues issues={issues} />,
            },
          ]}
        />
      </Modal>
    );
  }
}

const mapStateToProps = ({ clusterPage, clusterInstancePage, app }, { instanceUUID }) => {
  const {
    alias,
    disabled,
    message,
    status,
    uri,
    ro,
    replicaset: { uuid: replicasetUUID },
  } = clusterPage.serverList.find(({ uuid }) => uuid === instanceUUID) || {};

  const { labels, masterUUID, activeMasterUUID } = clusterInstancePage;

  const replicaset =
    clusterPage.replicasetList && clusterPage.replicasetList.find(({ uuid }) => uuid === replicasetUUID);

  const server = clusterPage.serverList.find(({ uuid }) => uuid === instanceUUID);

  return {
    alias,
    disabled,
    selfURI: app.clusterSelf.uri,
    failoverMode: app.failover_params.mode,
    issues: clusterPage.issues.filter(({ instance_uuid }) => instance_uuid === instanceUUID),
    labels,
    message,
    masterUUID,
    activeMasterUUID,
    replicaset,
    status,
    uri,
    zone: (server && server.zone) || null,
    zoneList: uniq(clusterPage.serverList.map(({ zone }) => zone)).filter((v) => v),
    instanceUUID: instanceUUID,
    ro,
  };
};

const mapDispatchToProps = {
  pageDidMount,
  resetPageState,
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(ServerDetailsModal));
