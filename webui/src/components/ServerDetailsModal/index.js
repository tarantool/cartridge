// @flow

import * as React from 'react'
import { connect } from 'react-redux'
import { css } from 'emotion';
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
  withPopover
} from '@tarantool.io/ui-kit';
import {
  pageDidMount,
  resetPageState
} from 'src/store/actions/clusterInstancePage.actions';
import { withRouter } from 'react-router-dom'
import {
  setInstanceZoneFx,
  chooseZoneFail,
  zoneAddModalOpen
} from 'src/store/effector/clusterZones';
import store from 'src/store/instance';
import { failoverPromoteLeader } from 'src/store/actions/clusterPage.actions';
import ServerDetailsModalStatTab from './ServerDetailsModalStatTab'
import { ServerDetailsModalIssues } from './ServerDetailsModalIssues'
import { HealthStatus } from '../HealthStatus';
import { ServerDropdown } from '../ServerDropdown';
import { LeaderLabel } from '../LeaderLabel';
import { graphqlErrorNotification } from '../../misc/graphqlErrorNotification';
import type { Issue, Replicaset } from 'src/generated/graphql-typing';

const styles = {
  firstLine: css`
    display: flex;
    justify-content: space-between;
    margin-bottom: 21px;
  `,
  leaderFlag: css`
    margin-left: 20px;
    margin-bottom: 3px;
    vertical-align: middle;
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
  `
};

const PopoverButton = withPopover(Button);

chooseZoneFail.watch(data => {
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
  zoneList: string[]
}

type ServerDetailsModalState = {
  selectedTab: ?string,
}

class ServerDetailsModal extends React.Component<
  ServerDetailsModalProps,
  ServerDetailsModalState
> {
  state = {
    selectedTab: null
  }

  static tabsOrder = [
    'general',
    'cartridge',
    'replication',
    'storage',
    'network'
  ];

  componentDidMount() {
    this.props.pageDidMount({
      instanceUUID: this.props.instanceUUID
    });
  }

  componentWillUnmount() {
    this.props.resetPageState();
  }

  close = () => {
    this.props.history.push('/cluster/dashboard')
  }

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
      zoneList
    } = this.props

    const activeMaster = instanceUUID === activeMasterUUID;
    const master = instanceUUID === masterUUID;
    const showFailoverPromote = replicaset.servers
      && replicaset.servers.length > 1 && failoverMode === 'stateful';

    return (
      <Modal
        className='meta-test__ServerDetailsModal'
        title={<>
          <span className={styles.headingWidthLimit}>{alias || instanceUUID}</span>
          {(master || activeMaster) && (
            <LeaderLabel
              className={styles.leaderFlag}
              state={status !== 'healthy' ? 'bad' : ro === false ? 'good' : 'warning'}
            />
          )}
        </>}
        footerControls={[
          <Button onClick={this.close} text='Close' size='l' />
        ]}
        visible={true}
        onClose={this.close}
        wide
      >
        <div className={styles.firstLine}>
          <div>
            <UriLabel
              weAreHere={selfURI && uri === selfURI}
              className={selfURI && uri === selfURI && 'meta-test__youAreHereIcon'}
              title='URI'
              uri={uri}
            />
            <HealthStatus status={status} message={message} />
          </div>
          <ControlsPanel
            controls={[
              <PopoverButton
                intent='secondary'
                text={zone ? 'Zone ' + zone : 'Select zone'}
                size='l'
                iconRight={IconChevronDown}
                popoverClassName={styles.popover}
                // TODO: add loading state while applying
                popoverContent={<>
                  {zoneList.map(zoneName => (
                    <DropdownItem
                      key={zoneName}
                      onClick={() => setInstanceZoneFx({ uuid: instanceUUID, zone: zone === zoneName ? '' : zoneName })}
                      className='meta-test__ZoneListItem'
                    >
                      {zoneName}
                    </DropdownItem>
                  ))}
                  {zoneList.length
                    ? <DropdownDivider />
                    : (
                      <Text
                        className={styles.noZoneLabel}
                        variant='p'
                        tag='div'
                        onClick={e => e.stopPropagation()}
                      >
                        {'You have no any zone,\nplease add one.'}
                      </Text>
                    )}
                  <Button
                    className={styles.zoneAddBtn}
                    size='l'
                    intent='secondary'
                    text='Add new zone'
                    onClick={() => zoneAddModalOpen(instanceUUID)}
                  />
                </>}
              />,
              ...(showFailoverPromote && replicaset)
                ? [
                  <Button
                    intent='secondary'
                    text={activeMaster ? 'Force promote' : 'Promote'}
                    size='l'
                    onClick={() => {
                      store.dispatch(failoverPromoteLeader(
                        replicaset.uuid,
                        instanceUUID,
                        activeMaster
                      ));
                      this.close();
                    }}
                  />
                ]
                : [],
              replicaset && (
                <ServerDropdown
                  disabled={disabled}
                  intent='secondary'
                  activeMaster={activeMaster}
                  replicasetUUID={replicaset.uuid}
                  uri={uri}
                  history={history}
                  uuid={instanceUUID}
                  size='l'
                />
              )
            ]}
            thin
          />
        </div>
        <Tabbed
          tabs={
            [
              ...filter(identity, ServerDetailsModal.tabsOrder).map(section => ({
                label: section[0].toUpperCase() + section.substring(1),
                content: (<ServerDetailsModalStatTab sectionName={section}/>)
              })),
              {
                label: 'Issues ' + issues.length,
                content: <ServerDetailsModalIssues issues={issues} />
              }
            ]
          }
        />
      </Modal>
    )
  }
}

const mapStateToProps = (
  {
    clusterPage,
    clusterInstancePage,
    app
  },
  { instanceUUID }
) => {
  const {
    alias,
    disabled,
    message,
    status,
    uri,
    ro,
    replicaset: { uuid: replicasetUUID }
  } = clusterPage.serverList.find(({ uuid }) => uuid === instanceUUID) || {};

  const {
    labels,
    masterUUID,
    activeMasterUUID
  } = clusterInstancePage;

  const replicaset = clusterPage.replicasetList
    && clusterPage.replicasetList.find(({ uuid }) => uuid === replicasetUUID);

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
    zoneList: uniq(clusterPage.serverList.map(({ zone }) => zone)).filter(v => v),
    instanceUUID: instanceUUID,
    ro
  };
};

const mapDispatchToProps = {
  pageDidMount,
  resetPageState
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(ServerDetailsModal));
