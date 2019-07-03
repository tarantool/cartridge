import React from 'react';
import { defaultMemoize } from 'reselect';
import * as R from 'ramda';
import { Icon } from 'antd'
import { css } from 'react-emotion';
import { getServerName } from 'src/app/misc';
import AppBottomConsole from 'src/components/AppBottomConsole';
import Input from 'src/components/Input';
import ServerConsole from 'src/components/ServerConsole';
import Modal from 'src/components/Modal';
import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import ReplicasetEditModal from 'src/components/ReplicasetEditModal';
import ReplicasetList from 'src/components/ReplicasetList';
import ServerEditModal from 'src/components/ServerEditModal';
import ServerList from 'src/components/ServerList';
import { addSearchParams, getSearchParams } from 'src/misc/url';
import ClusterConfigManagement from 'src/components/ClusterConfigManagement';
import PageSectionHead from 'src/components/PageSectionHead';
import './Cluster.css';
import BootstrapPanel from "src/components/BootstrapPanel";
import Button from 'src/components/Button';
import FailoverButton from './child/FailoverButton';
import AuthToggleButton from 'src/components/AuthToggleButton';

const styles = {
  clusterFilter: css`
    width: 100%;
    padding-bottom: 10px;
    padding-left: 5px;
    padding-top: 10px;
    box-shadow: 0px 5px 5px 0px #FAFAFA;
    background: #FAFAFA;
    margin-bottom: 10px;
    position: sticky;
    top: 0px;
    z-index: 4;
  `,
};

/*
  [Probe server]                         => renderProbeServerModal         => ServerEditModal (create: set uri, skip replicaset)
  ServerList > [Join]                    => renderJoinServerModal          => ServerEditModal (edit: skip uri, set replicaset)
  ServerList > [Create]                  => renderCreateReplicasetModal    => ReplicasetEditModal (create: set roles)
  ReplicasetList > ServerList > [Expel]  => renderExpelServerConfirmModal  => confirmation
  ReplicasetList > [Edit]                => renderEditReplicasetModal      => ReplicasetEditModal (edit: set roles)
 */

const prepareReplicasetList = (replicasetList, serverStat, rolesFilterValue, nameFilterValue) => {
  return replicasetList.map(replicaset => {
    const servers = replicaset.servers.map(server => {
      const stat = serverStat.find(stat => stat.uuid === server.uuid);
      return {
        ...server,
        statistics: stat ? stat.statistics : null,
      };
    });
    return {
      ...replicaset,
      servers,
    };
  });
};

const filterReplicasetList = (replicasetList, filter) => {
  const tokenizedFilter = filter.toLowerCase().split(' ').map(x => x.trim()).filter(x => !!x);

  const searchableList = replicasetList.map(r => {
    let searchIndex = [...r.roles];
    r.servers.forEach(s => {
      searchIndex.push(s.uri, (s.alias || ''));
      s.labels.forEach(({ name, value }) => searchIndex.push(`${name}:`, value));
    });

    const searchString = searchIndex.join(' ').toLowerCase();

    return {
      ...r,
      searchString
    }
  });

  const filterByTokens = R.filter(
    R.allPass(
      tokenizedFilter.map(token => r => r.searchString.includes(token) || r.uuid.startsWith(token))
    )
  );

  return filterByTokens(searchableList);
};

class Cluster extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      serverConsoleVisible: false,
      serverConsoleUuid: null,
      bootstrapVshardConfirmVisible: false,
      bootstrapVshardConfirmDataSource: null,
      probeServerModalVisible: false,
      joinServerModalVisible: false,
      joinServerModalDataSource: null,
      createReplicasetModalVisible: false,
      createReplicasetModalDataSource: null,
      expelServerConfirmVisible: false,
      expelServerConfirmDataSource: null,
      rolesFilterValue: '',
      nameFilterValue: '',
      filter: '',
    };

    this.consoleReserveElement = null;

    this.prepareReplicasetList = defaultMemoize(prepareReplicasetList);
    this.filterReplicasetList = defaultMemoize(filterReplicasetList);
  }

  componentDidMount() {
    const {
      pageDidMount,
      location,
    } = this.props;

    const selectedServerUri = getSearchParams(location.search).s || null;
    const selectedReplicasetUuid = getSearchParams(location.search).r || null;

    pageDidMount({
      selectedServerUri,
      selectedReplicasetUuid,
      checkTestConfigApplyingAbility: true,
    });
  }

  componentDidUpdate() {
    this.checkOnServerPopupStateChange();
    this.checkOnReplicasetPopupStateChange();
  }

  componentWillUnmount() {
    const { resetPageState } = this.props;

    const connectedServer = this.getConnectedServer();
    resetPageState({
      consoleKey: connectedServer ? connectedServer.uuid : null,
      consoleState: connectedServer ? this.console.getConsoleState() : null,
    });
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
      selectedServerUri,
      replicasetList,
      selectedReplicasetUuid,
      showBootstrapModal
    } = this.props;

    const {
      serverConsoleVisible,
      probeServerModalVisible,
      createReplicasetModalVisible,
      expelServerConfirmVisible,
      filter
    } = this.state;

    const joinServerModalVisible = !!selectedServerUri;
    const editReplicasetModalVisible = !!selectedReplicasetUuid;
    const unlinkedServers = this.getUnlinkedServers();
    const filteredReplicasetList = this.filterReplicasetList(this.getReplicasetList(), filter);
    const isBootstrap = (clusterSelf && clusterSelf.uuid) || false;

    return (
      <React.Fragment>
        {showBootstrapModal
          ? this.renderBootstrapVshardConfirmModal()
          : null}
        {probeServerModalVisible
          ? this.renderProbeServerModal()
          : null}
        {joinServerModalVisible
          ? this.renderJoinServerModal()
          : null}
        {createReplicasetModalVisible
          ? this.renderCreateReplicasetModal()
          : null}
        {expelServerConfirmVisible
          ? this.renderExpelServerConfirmModal()
          : null}
        {editReplicasetModalVisible
          ? this.renderEditReplicasetModal()
          : null}
        {serverConsoleVisible
          ? this.renderServerConsole()
          : null}
        <div className="pages-Cluster app-content">
          <div className="page-inner">
            {unlinkedServers.length
              ? (
                <div className="tr-card-margin">
                  <PageSectionHead
                    title="Replica sets"
                    buttons={this.renderServerButtons()}
                  />
                  <div className="pages-Cluster-serverList">
                    <ServerList
                      linked={false}
                      clusterSelf={clusterSelf}
                      dataSource={unlinkedServers}
                      consoleServer={this.handleServerConsoleRequest}
                      joinServer={this.handleJoinServerRequest}
                      expelServer={this.handleExpelServerRequest}
                      createReplicaset={this.handleCreateReplicasetRequest} />
                  </div>
                </div>
              )
              : null
            }

            <BootstrapPanel />

            {replicasetList.length
              ? (
                <div className="tr-card-margin pages-Cluster-replicasetList">
                  <PageSectionHead
                    thin={true}
                    title="Replica sets"
                    buttons={
                      unlinkedServers.length
                        ? null
                        : this.renderServerButtons()
                    }
                  />

                  {replicasetList.length > 1
                    ? (
                      <div className={styles.clusterFilter}>
                        <Input
                          prefix={<Icon type="search" />}
                          type={"text"}
                          placeholder={'Filter by uri, uuid, role, alias or labels'}
                          value={this.state.filter}
                          onChange={this.handleFilterChange}
                        />
                      </div>
                    )
                    : null}

                  {filteredReplicasetList.length
                    ? (
                      <ReplicasetList
                        clusterSelf={clusterSelf}
                        dataSource={filteredReplicasetList}
                        consoleServer={this.handleServerConsoleRequest}
                        editReplicaset={this.handleEditReplicasetRequest}
                        joinServer={this.handleJoinServerRequest}
                        expelServer={this.handleExpelServerRequest}
                        createReplicaset={this.handleCreateReplicasetRequest}
                        onServerLabelClick={this.handleServerLabelClick}
                      />
                    )
                    : (
                      <div className="trTable-noData">
                        No replicaset found
                      </div>
                    )}
                </div>
              )
              : null
            }

            {isBootstrap && <ClusterConfigManagement
              uploadConfig={this.uploadConfig}
              canTestConfigBeApplied={false}
              applyTestConfig={this.applyTestConfig} />}
            <div ref={this.setConsoleReserve} />
          </div>
        </div>
      </React.Fragment>
    );
  };

  renderServerConsole = () => {
    const { clusterSelf, evalResult, serverList } = this.props;

    const connectedServerSavedConsoleState = this.getConnectedServerSavedConsoleState();
    const connectedServer = this.getConnectedServer();
    const serverName = getServerName(clusterSelf, connectedServer);

    return (
      <AppBottomConsole
        title={serverName}
        onClose={this.handleCloseServerConsoleRequest}
        onSizeChange={this.updateConsoleReserveHeight}
      >
        <ServerConsole
          ref={this.setConsole}
          autofocus
          initialState={connectedServerSavedConsoleState}
          clusterSelf={clusterSelf}
          server={connectedServer}
          serverList={serverList}
          handler={this.evalString}
          result={evalResult} />
      </AppBottomConsole>
    );
  };

  renderServerButtons = () => {
    const { showToggleAuth } = this.props;
    return ([
      <FailoverButton />,
      showToggleAuth && <AuthToggleButton />,
      <Button
        size={'large'}
        onClick={this.handleProbeServerRequest}
      >
        Probe server
      </Button>
    ]);
  };

  renderBootstrapVshardConfirmModal = () => {
    return (
      <Modal
        visible
        width={691}
        onOk={this.handleBootstrapVshardSubmitRequest}
        onCancel={this.handleBootstrapVshardConfirmCloseRequest}
      >
        Do you really want to bootstrap vshard?
      </Modal>
    );
  };

  renderProbeServerModal = () => {
    return (
      <ServerEditModal
        shouldCreateServer
        onSubmit={this.handleProbeServerSubmitRequest}
        onRequestClose={this.handleProbeServerModalCloseRequest} />
    );
  };

  renderJoinServerModal = () => {
    const { pageMount, pageDataRequestStatus } = this.props;

    const pageDataLoading = !pageMount || !pageDataRequestStatus.loaded || pageDataRequestStatus.loading;
    const server = this.getSelectedServer();
    const serverNotFound = pageDataLoading ? null : !server;
    const replicasetList = this.getReplicasetList();

    return (
      <ServerEditModal
        isLoading={pageDataLoading}
        serverNotFound={serverNotFound}
        server={server}
        replicasetList={replicasetList}
        onSubmit={this.handleJoinServerSubmitRequest}
        onRequestClose={this.handleJoinServerModalCloseRequest} />
    );
  };

  renderCreateReplicasetModal = () => {
    return (
      <ReplicasetEditModal
        shouldCreateReplicaset
        onSubmit={this.handleCreateReplicasetSubmitRequest}
        onRequestClose={this.handleCreateReplicasetModalCloseRequest} />
    );
  };

  renderExpelServerConfirmModal = () => {
    const { expelServerConfirmDataSource } = this.state;

    return (
      <Modal
        visible
        width={691}
        onOk={this.handleExpelServerSubmitRequest}
        onCancel={this.handleExpelServerConfirmCloseRequest}
      >
        Do you really want to expel the server {expelServerConfirmDataSource.uri}?
      </Modal>
    );
  };

  renderEditReplicasetModal = () => {
    const { pageMount, pageDataRequestStatus } = this.props;

    const pageDataLoading = !pageMount || !pageDataRequestStatus.loaded || pageDataRequestStatus.loading;
    const replicaset = this.getSelectedReplicaset();
    const replicasetNotFound = pageDataLoading ? null : !replicaset;

    return (
      <ReplicasetEditModal
        isLoading={pageDataLoading}
        replicasetNotFound={replicasetNotFound}
        replicaset={replicaset}
        onSubmit={this.handleEditReplicasetSubmitRequest}
        onRequestClose={this.handleEditReplicasetModalCloseRequest} />
    );
  };

  setConsole = ref => {
    this.console = ref;
  };

  setConsoleReserve = ref => {
    this.consoleReserveElement = ref;
  };

  updateConsoleReserveHeight = size => {
    this.consoleReserveElement.style.height = `${size.height}px`;
  };

  checkOnServerPopupStateChange = () => {
    const { location, selectedServerUri } = this.props;

    const locationSelectedServerUri = getSearchParams(location.search).s || null;

    if (locationSelectedServerUri !== selectedServerUri) {
      if (locationSelectedServerUri) {
        const { selectServer } = this.props;
        selectServer({ uri: locationSelectedServerUri });
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
        selectReplicaset({ uuid: locationSelectedReplicasetUuid });
      } else {
        const { closeReplicasetPopup } = this.props;
        closeReplicasetPopup();
      }
    }
  };

  evalString = consoleAction => {
    const { evalString } = this.props;
    const connectedServer = this.getConnectedServer();
    evalString({
      uri: connectedServer.uri,
      text: consoleAction.command,
    });
  };

  handleServerConsoleRequest = server => {
    const { serverConsoleVisible, serverConsoleUuid } = this.state;

    if (serverConsoleVisible && serverConsoleUuid !== server.uuid) {
      this.saveConnectedServerConsoleState();
    }

    this.setState({
      serverConsoleVisible: true,
      serverConsoleUuid: server.uuid,
    });
  };

  handleServerLabelClick = ({ name, value }) => this.setState({ filter: `${name}: ${value}` });

  handleCloseServerConsoleRequest = () => {
    this.saveConnectedServerConsoleState();
    this.setState({
      serverConsoleVisible: false,
      serverConsoleUuid: null,
    });
    this.updateConsoleReserveHeight({ height: 0 });
  };

  handleBootstrapVshardConfirmCloseRequest = () => {
    this.props.setVisibleBootstrapVshardModal(false);
  };

  handleBootstrapVshardSubmitRequest = () => {
    const { bootstrapVshard } = this.props;
    bootstrapVshard();
  };

  handleProbeServerRequest = () => {
    this.setState({ probeServerModalVisible: true });
  };

  handleProbeServerModalCloseRequest = () => {
    this.setState({ probeServerModalVisible: false });
  };

  handleProbeServerSubmitRequest = server => {
    const { probeServer } = this.props;
    this.setState(
      {
        probeServerModalVisible: false,
      },
      () => probeServer({ uri: server.uri }),
    );
  };

  handleJoinServerRequest = server => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { s: server.uri }),
    });
  };

  handleJoinServerModalCloseRequest = () => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { s: null }),
    });
  };

  handleJoinServerSubmitRequest = server => {
    const { joinServer, history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { s: null }),
    });
    joinServer({
      ...server,
      uuid: server.replicasetUuid,
    });
  };

  handleCreateReplicasetRequest = server => {
    this.setState({
      createReplicasetModalVisible: true,
      createReplicasetModalDataSource: server,
    });
  };

  handleCreateReplicasetModalCloseRequest = () => {
    this.setState({
      createReplicasetModalVisible: false,
      createReplicasetModalDataSource: null,
    });
  };

  handleCreateReplicasetSubmitRequest = replicaset => {
    const { createReplicaset } = this.props;
    const { createReplicasetModalDataSource } = this.state;
    this.setState(
      {
        createReplicasetModalVisible: false,
        createReplicasetModalDataSource: null,
      },
      () => createReplicaset({
        ...createReplicasetModalDataSource,
        roles: replicaset.roles,
        vshard_group: replicaset.vshard_group
      }),
    );
  };

  handleExpelServerRequest = server => {
    this.setState({
      expelServerConfirmVisible: true,
      expelServerConfirmDataSource: server,
    });
  };

  handleExpelServerConfirmCloseRequest = () => {
    this.setState({
      expelServerConfirmVisible: false,
      expelServerConfirmDataSource: null,
    });
  };

  handleExpelServerSubmitRequest = () => {
    const { expelServer } = this.props;
    const { expelServerConfirmDataSource } = this.state;
    this.setState(
      {
        expelServerConfirmVisible: false,
        expelServerConfirmDataSource: null,
      },
      () => expelServer(expelServerConfirmDataSource),
    );
  };

  handleEditReplicasetRequest = replicaset => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { r: replicaset.uuid }),
    });
  };

  handleEditReplicasetModalCloseRequest = () => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { r: null }),
    });
  };

  handleEditReplicasetSubmitRequest = replicaset => {
    const { editReplicaset, history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { r: null }),
    });

    const getMaster = () => {
      if (replicaset.servers.length > 2) {
        return replicaset.servers.map(i => i.uuid);
      }
      return replicaset.master;
    };

    editReplicaset({
      uuid: replicaset.uuid,
      roles: replicaset.roles,
      vshard_group: replicaset.vshard_group,
      master: getMaster(),
      weight: replicaset.weight == null || replicaset.weight.trim() === '' ? null : Number(replicaset.weight),
    });
  };

  handleRolesFilterChange = event => {
    const { target } = event;
    this.setState({
      rolesFilterValue: target.value,
    });
  };

  handleNameFilterChange = event => {
    const { target } = event;
    this.setState({
      nameFilterValue: target.value,
    });
  };

  handleResetFilterClick = () => {
    this.setState({
      rolesFilterValue: '',
      nameFilterValue: '',
    });
  };

  handleFilterChange = e => {
    const value = e.target.value;
    this.setState(() => ({
      filter: value
    }))
  }

  saveConnectedServerConsoleState = () => {
    const { saveConsoleState } = this.props;

    const connectedServer = this.getConnectedServer();
    saveConsoleState({
      consoleKey: connectedServer.uuid,
      consoleState: this.console.getConsoleState(),
    });
  };

  uploadConfig = data => {
    const { uploadConfig } = this.props;
    uploadConfig(data);
  };

  applyTestConfig = () => {
    const { serverList, applyTestConfig } = this.props;
    applyTestConfig({ uri: serverList[0].uri });
  };

  getConnectedServer = () => {
    const { serverList } = this.props;
    const { serverConsoleUuid } = this.state;
    return serverList ? serverList.find(server => server.uuid === serverConsoleUuid) : null;
  };

  getConnectedServerSavedConsoleState = () => {
    const { savedConsoleState } = this.props;
    const connectedServer = this.getConnectedServer();
    const savedConsoleInstanceState = savedConsoleState[connectedServer.uuid];
    return savedConsoleInstanceState && savedConsoleInstanceState.state;
  };

  getUnlinkedServers = () => {
    const { serverList } = this.props;
    return serverList ? serverList.filter(server => !server.replicaset) : null;
  };

  getSelectedServer = () => {
    const { serverList, selectedServerUri } = this.props;
    return serverList ? serverList.find(server => server.uri === selectedServerUri) : null;
  };

  getSelectedReplicaset = () => {
    const { selectedReplicasetUuid } = this.props;
    const replicasetList = this.getReplicasetList();
    return replicasetList
      ? replicasetList.find(replicaset => replicaset.uuid === selectedReplicasetUuid)
      : null;
  };

  getReplicasetList = () => {
    const { replicasetList, serverStat } = this.props;

    return replicasetList
      ? this.prepareReplicasetList(replicasetList, serverStat)
      : null;
  };
}

export default Cluster;
