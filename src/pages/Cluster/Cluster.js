import React from 'react';
import { defaultMemoize } from 'reselect';

import { getServerName } from 'src/app/misc';
import AppBottomConsole from 'src/components/AppBottomConsole';
import ClusterConfigManagement from 'src/components/ClusterConfigManagement';
import ServerConsole from 'src/components/ServerConsole';
import Modal from 'src/components/Modal';
import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import ReplicasetEditModal from 'src/components/ReplicasetEditModal';
import ReplicasetList from 'src/components/ReplicasetList';
import ServerEditModal from 'src/components/ServerEditModal';
import ServerList from 'src/components/ServerList';
import { addSearchParams, getSearchParams } from 'src/misc/url';

import './Cluster.css';

/*
  [Probe server]                         => renderProbeServerModal         => ServerEditModal (create: set uri, skip replicaset)
  ServerList > [Join]                    => renderJoinServerModal          => ServerEditModal (edit: skip uri, set replicaset)
  ServerList > [Create]                  => renderCreateReplicasetModal    => ReplicasetEditModal (create: set roles)
  ReplicasetList > ServerList > [Expell] => renderExpellServerConfirmModal => confirmation
  ReplicasetList > [Edit]                => renderEditReplicasetModal      => ReplicasetEditModal (edit: set roles)
 */

const prepareReplicasetList = (replicasetList, serverStat) => {
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

class Cluster extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      serverConsoleVisible: false,
      serverConsoleUuid: null,
      probeServerModalVisible: false,
      joinServerModalVisible: false,
      joinServerModalDataSource: null,
      createReplicasetModalVisible: false,
      createReplicasetModalDataSource: null,
      expellServerConfirmVisible: false,
      expellServerConfirmDataSource: null,
    };

    this.consoleReserveElement = null;

    this.prepareReplicasetList = defaultMemoize(prepareReplicasetList);
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

    return ! pageDataRequestStatus.loaded
      ? null
      : pageDataRequestStatus.error
        ? <PageDataErrorMessage error={pageDataRequestStatus.error}/>
        : this.renderContent();
  }

  renderContent = () => {
    const { clusterSelf, serverList, selectedServerUri, selectedReplicasetUuid } = this.props;
    const { serverConsoleVisible, probeServerModalVisible, createReplicasetModalVisible, expellServerConfirmVisible }
      = this.state;

    const joinServerModalVisible = !!selectedServerUri;
    const editReplicasetModalVisible = !!selectedReplicasetUuid;
    const unlinkedServers = this.getUnlinkedServers();
    const replicasetList = this.getReplicasetList();
    const canTestConfigBeApplied = !!serverList && serverList.length === 1 && serverList[0].status === 'unconfigured';

    return (
      <React.Fragment>
        {probeServerModalVisible
          ? this.renderProbeServerModal()
          : null}
        {joinServerModalVisible
          ? this.renderJoinServerModal()
          : null}
        {createReplicasetModalVisible
          ? this.renderCreateReplicasetModal()
          : null}
        {expellServerConfirmVisible
          ? this.renderExpellServerConfirmModal()
          : null}
        {editReplicasetModalVisible
          ? this.renderEditReplicasetModal()
          : null}
        {serverConsoleVisible
          ? this.renderServerConsole()
          : null}

        <div className="pages-Cluster page-outer app-content">
          <div className="page-inner">
            <div className="container">
              {unlinkedServers.length
                ? (
                  <div className="tr-card-margin">
                    <div className="tr-card-head">
                      <div className="tr-card-header">
                        Unconfigured instances
                      </div>
                      <div className="tr-cards-buttons">
                        {this.renderProbeServerButton()}
                      </div>
                    </div>
                    <div className="pages-Cluster-serverList">
                      <ServerList
                        linked={false}
                        clusterSelf={clusterSelf}
                        dataSource={unlinkedServers}
                        consoleServer={this.handleServerConsoleRequest}
                        joinServer={this.handleJoinServerRequest}
                        expellServer={this.handleExpellServerRequest}
                        createReplicaset={this.handleCreateReplicasetRequest} />
                    </div>
                  </div>
                )
                : null}

              {replicasetList.length
                ? (
                  <div className="tr-card-margin">
                    <div className="tr-card-head">
                      <div className="tr-card-header">
                        Replicaset list
                      </div>
                      <div className="tr-cards-buttons">
                        {unlinkedServers.length
                          ? null
                          : this.renderProbeServerButton()}
                      </div>
                    </div>
                    <div className="pages-Cluster-replicasetList">
                      <ReplicasetList
                        clusterSelf={clusterSelf}
                        dataSource={replicasetList}
                        consoleServer={this.handleServerConsoleRequest}
                        editReplicaset={this.handleEditReplicasetRequest}
                        joinServer={this.handleJoinServerRequest}
                        expellServer={this.handleExpellServerRequest}
                        createReplicaset={this.handleCreateReplicasetRequest} />
                    </div>
                  </div>
                )
                : null}

              <div className="pages-Cluster-configurationCard tr-card">
                <div className="tr-card-head">
                  <div className="tr-card-header">
                    Configuration
                  </div>
                </div>
                <div className="tr-card-content">
                  <ClusterConfigManagement
                    isConfingApplying={false}
                    canTestConfigBeApplied={canTestConfigBeApplied}
                    uploadConfig={this.uploadConfig}
                    applyTestConfig={this.applyTestConfig} />
                </div>
              </div>
            </div>
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

  renderProbeServerButton = () => {
    return (
      <button
        type="button"
        className="btn btn-light btn-sm"
        onClick={this.handleProbeServerRequest}
      >
        Probe server
      </button>
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

    const pageDataLoading = ! pageMount || ! pageDataRequestStatus.loaded || pageDataRequestStatus.loading;
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

  renderExpellServerConfirmModal = () => {
    const { expellServerConfirmDataSource } = this.state;

    return (
      <Modal
        visible
        width={540}
        onOk={this.handleExpellServerSubmitRequest}
        onCancel={this.handleExpellServerConfirmCloseRequest}
      >
        Are you really want to expell server {expellServerConfirmDataSource.uri}?
      </Modal>
    );
  };

  renderEditReplicasetModal = () => {
    const { pageMount, pageDataRequestStatus } = this.props;

    const pageDataLoading = ! pageMount || ! pageDataRequestStatus.loaded || pageDataRequestStatus.loading;
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

  handleCloseServerConsoleRequest = () => {
    this.saveConnectedServerConsoleState();
    this.setState({
      serverConsoleVisible: false,
      serverConsoleUuid: null,
    });
    this.updateConsoleReserveHeight({ height: 0 });
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
      () => probeServer(server),
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
      }),
    );
  };

  handleExpellServerRequest = server => {
    this.setState({
      expellServerConfirmVisible: true,
      expellServerConfirmDataSource: server,
    });
  };

  handleExpellServerConfirmCloseRequest = () => {
    this.setState({
      expellServerConfirmVisible: false,
      expellServerConfirmDataSource: null,
    });
  };

  handleExpellServerSubmitRequest = () => {
    const { expellServer } = this.props;
    const { expellServerConfirmDataSource } = this.state;
    this.setState(
      {
        expellServerConfirmVisible: false,
        expellServerConfirmDataSource: null,
      },
      () => expellServer(expellServerConfirmDataSource),
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
    editReplicaset(replicaset);
  };

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
    return serverList ? serverList.filter(server => ! server.replicaset) : null;
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
