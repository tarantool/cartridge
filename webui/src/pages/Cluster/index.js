// @flow
import { connect } from 'react-redux';
import {
  pageDidMount,
  selectServer,
  closeServerPopup,
  selectReplicaset,
  closeReplicasetPopup,
  uploadConfig,
  applyTestConfig,
  resetPageState,
  setFilter
} from 'src/store/actions/clusterPage.actions';
import {
  getReplicasetCounts,
  getServerCounts,
  filterReplicasetListSelector,
  selectReplicasetListWithStat
} from 'src/store/selectors/clusterPage';
import type { State } from 'src/store/rootReducer';
import * as React from 'react';
import { css, cx } from 'react-emotion';
import type { RouterHistory, Location } from 'react-router';
import type { Issue } from 'src/generated/graphql-typing';
import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import ReplicasetList from 'src/components/ReplicasetList';
import UnconfiguredServerList from 'src/components/UnconfiguredServerList';
import { addSearchParams, getSearchParams } from 'src/misc/url';
import EditReplicasetModal from 'src/components/EditReplicasetModal';
import ConfigureServerModal from 'src/components/ConfigureServerModal';
import ClusterButtonsPanel from 'src/components/ClusterButtonsPanel';
import BootstrapPanel from 'src/components/BootstrapPanel';
import {
  IconSearch,
  Input,
  PageSection,
  Dropdown,
  DropdownItem,
  DropdownDivider,
  Scrollbar,
  Button,
  IconChevron
} from '@tarantool.io/ui-kit';
import type { AppState } from 'src/store/reducers/ui.reducer';
import type {
  Label,
  Replicaset,
  Server
} from 'src/generated/graphql-typing.js';
import type { RequestStatusType } from 'src/store/commonTypes';
import type {
  PageDidMountActionCreator,
  ResetPageStateActionCreator,
  SelectReplicasetActionCreator,
  SelectServerActionCreator,
  SetFilterActionCreator,
  UploadConfigActionCreator
} from 'src/store/actions/clusterPage.actions';
import type { ReplicasetCounts, ServerCounts } from 'src/store/selectors/clusterPage';
import ExpelServerModal from '../../components/ExpelServerModal';
import ServerInfoModal from '../../components/ServerInfoModal';

const styles = {
  clusterFilter: css`
    width: 385px;
    position: relative;
  `
};

export type ClusterProps = {
  clusterSelf: $PropertyType<AppState, 'clusterSelf'>,
  issues: Issue[],
  pageMount: boolean,
  pageDataRequestStatus: RequestStatusType,
  replicasetCounts: ReplicasetCounts,
  selectedServerUri: ?string,
  selectedReplicasetUuid: ?string,
  serverList: ?Server[],
  serverCounts: ServerCounts,
  filter: string,
  replicasetList: Replicaset[],
  filteredReplicasetList: Replicaset[],
  history: RouterHistory,
  location: Location,

  pageDidMount: PageDidMountActionCreator,
  selectServer: SelectServerActionCreator,
  closeServerPopup: () => void,
  selectReplicaset: SelectReplicasetActionCreator,
  closeReplicasetPopup: () => void,
  expelServer: (s: Server) => void,
  uploadConfig: UploadConfigActionCreator,
  applyTestConfig: (p: {
    uri: ?string
  }) => void,
  createMessage: () => void,
  resetPageState: ResetPageStateActionCreator,
  setFilter: SetFilterActionCreator,
  routerParams: null | { instanceUUID: string },
};

class Cluster extends React.Component<ClusterProps> {
  componentDidMount() {
    const {
      pageDidMount,
      location
    } = this.props;

    const selectedServerUri = getSearchParams(location.search).s || null;
    const selectedReplicasetUuid = getSearchParams(location.search).r || null;

    pageDidMount(selectedServerUri, selectedReplicasetUuid);
  }

  componentDidUpdate() {
    this.checkOnServerPopupStateChange();
    this.checkOnReplicasetPopupStateChange();
  }

  componentWillUnmount() {
    this.props.resetPageState();
  }

  render() {
    const { pageDataRequestStatus } = this.props;

    return !pageDataRequestStatus.loaded
      ? null
      : pageDataRequestStatus.error
        ? <PageDataErrorMessage error={pageDataRequestStatus.error} />
        : this.renderContent();
  }

  renderContent = () => {
    const {
      clusterSelf,
      filter,
      filteredReplicasetList,
      issues,
      replicasetList,
      routerParams,
      serverCounts
    } = this.props;

    const unlinkedServers = this.getUnlinkedServers();

    return (
      <React.Fragment>
        {
          routerParams && routerParams.instanceUUID
            ?
            <ServerInfoModal instanceUUID={routerParams.instanceUUID} key={routerParams.instanceUUID} />
            :
            null
        }
        <ExpelServerModal />
        <EditReplicasetModal />
        <ConfigureServerModal />
        <ClusterButtonsPanel />
        <BootstrapPanel />
        {unlinkedServers && unlinkedServers.length
          ? (
            <PageSection
              title='Unconfigured servers'
              // topRightControls={[
              //   <Button
              //     disabled
              //     icon={IconGear}
              //     size='s'
              //     text='Configure selected'
              //   />
              // ]}
              subTitle={
                <React.Fragment>
                  <b>{serverCounts.unconfigured}</b>
                  {` Unconfigured server${serverCounts.unconfigured > 1 ? 's' : ''}`}
                </React.Fragment>
              }
            >
              <UnconfiguredServerList
                clusterSelf={clusterSelf}
                dataSource={unlinkedServers}
                onServerConfigure={this.handleJoinServerRequest}
              />
            </PageSection>
          )
          : null
        }
        {!!replicasetList.length && (
          <PageSection
            subTitle={this.getReplicasetsTitleCounters()}
            title='Replica sets'
            topRightControls={[
              <Input
                className={cx(styles.clusterFilter, 'meta-test__Filter')}
                placeholder={'Filter by uri, uuid, role, alias or labels'}
                value={filter}
                onChange={this.handleFilterChange}
                onClearClick={this.handleFilterClear}
                rightIcon={<IconSearch />}
                leftElement={this.replicasetFilterPresetsDropdown}
              />
            ]}
          >
            {filteredReplicasetList.length
              ? (
                <ReplicasetList
                  clusterSelf={clusterSelf}
                  dataSource={filteredReplicasetList}
                  issues={issues}
                  onServerLabelClick={this.handleServerLabelClick}
                />
              )
              : (
                <div className="trTable-noData">
                  No replicaset found
                </div>
              )
            }
          </PageSection>
        )}
      </React.Fragment>
    );
  };

  checkOnServerPopupStateChange = () => {
    const { location, selectedServerUri } = this.props;

    const locationSelectedServerUri = getSearchParams(location.search).s || null;

    if (locationSelectedServerUri !== selectedServerUri) {
      if (locationSelectedServerUri) {
        const { selectServer } = this.props;
        selectServer(locationSelectedServerUri);
      } else {
        const { closeServerPopup } = this.props;
        closeServerPopup();
      }
    }
  };

  checkOnReplicasetPopupStateChange = () => {
    const { location, selectedReplicasetUuid } = this.props;

    const locationSelectedReplicasetUuid = getSearchParams(location.search).r || null;

    if (locationSelectedReplicasetUuid !== selectedReplicasetUuid) {
      if (locationSelectedReplicasetUuid) {
        const { selectReplicaset } = this.props;
        selectReplicaset(locationSelectedReplicasetUuid);
      } else {
        const { closeReplicasetPopup } = this.props;
        closeReplicasetPopup();
      }
    }
  };

  handleServerLabelClick = ({ name, value }: Label) => this.props.setFilter(`${name}: ${value}`);

  handleFilterClear = () => void this.props.setFilter('');

  handleJoinServerRequest = (server: Server) => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { s: server.uri })
    });
  };

  handleFilterChange = (e: SyntheticInputEvent<HTMLInputElement>) => void this.props.setFilter(e.target.value);

  uploadConfig = (data: { data: FormData }) => {
    const { uploadConfig } = this.props;
    uploadConfig(data);
  };

  applyTestConfig = () => {
    const { serverList, applyTestConfig } = this.props;
    if (serverList) {
      applyTestConfig({ uri: serverList[0].uri });
    }
  };

  getUnlinkedServers = (): ?Server[] => {
    const { serverList } = this.props;
    return serverList ? serverList.filter(server => !server.replicaset) : null;
  };

  getSelectedReplicaset = () => {
    const { replicasetList, selectedReplicasetUuid } = this.props;

    return replicasetList
      ? replicasetList.find(replicaset => replicaset.uuid === selectedReplicasetUuid)
      : null;
  };

  getReplicasetsTitleCounters = () => {
    const {
      filter,
      filteredReplicasetList,
    } = this.props;
    const { configured } = this.props.serverCounts;
    const { total, unhealthy } = this.props.replicasetCounts;
    return <React.Fragment>
      {filter
        ? <>
          <b>{filteredReplicasetList.length}{` selected | `}</b>
        </>
        :
        null
      }
      <b>{total}</b>{` total | `}
      <b>{unhealthy}</b>{` unhealthy | `}
      <b>{configured}</b>{` server${configured === 1 ? '' : 's'}`}
    </React.Fragment>;
  }

  getDropdownOption = prefix => option => (
    <DropdownItem
      onClick={() => this.props.setFilter(
        `${prefix}:${option.indexOf(' ') !== -1 ? `"${option.toLowerCase()}"` : option.toLowerCase()}`
      )}
    >
      {option}
    </DropdownItem>
  );

  replicasetFilterPresetsDropdown = (
    <Dropdown
      items={(
        <Scrollbar className={css`z-index: 10000; height: 250px; width: 10em;`}>
          {
            [
              'Healthy',
              'Unhealthy',
            ].map(this.getDropdownOption('status'))
          }
          <DropdownDivider />
          {
            [
              'Stateful Connector',
              'Input_processor',
              'Connector',
              'Scheduler',
              'Storage',
              'Task_runner',
            ].map(this.getDropdownOption('role'))
          }
        </Scrollbar>
      )}
    >
      <Button
        className={css`
          border-top-right-radius: 0;
          border-bottom-right-radius: 0;
          height: 2.4em;
          width: 6.5em;
        `}
        intent='secondary'
        iconRight={() => (
          <IconChevron
            direction='down'
            className={css`margin-left: .5em; fill: rgba(245, 34, 45, 0.65);`}
          />
        )}
      >
        Filter
      </Button>
    </Dropdown>
  )
}


const mapStateToProps = (state: State, { match: { params } }) => {
  const {
    app: { clusterSelf },
    clusterPage: {
      issues,
      pageMount,
      pageDataRequestStatus,
      replicasetFilter,
      selectedServerUri,
      selectedReplicasetUuid,
      serverList
    }
  } = state;

  const replicasetList = selectReplicasetListWithStat(state);

  return {
    clusterSelf,
    filter: replicasetFilter,
    filteredReplicasetList: replicasetFilter
      ? filterReplicasetListSelector(state)
      : replicasetList,
    issues,
    pageMount,
    pageDataRequestStatus,
    replicasetCounts: getReplicasetCounts(state),
    replicasetList,
    selectedServerUri,
    selectedReplicasetUuid,
    serverList,
    serverCounts: getServerCounts(state),
    routerParams: params
  };
};

const mapDispatchToProps = {
  pageDidMount,
  selectServer,
  closeServerPopup,
  selectReplicaset,
  closeReplicasetPopup,
  uploadConfig,
  applyTestConfig,
  resetPageState,
  setFilter
};

export default connect(mapStateToProps, mapDispatchToProps)(Cluster);
