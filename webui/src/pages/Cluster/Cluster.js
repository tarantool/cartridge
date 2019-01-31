import React from 'react';
import { defaultMemoize } from 'reselect';

import { getServerName } from 'src/app/misc';
import AppBottomConsole from 'src/components/AppBottomConsole';
import ClusterConfigManagement from 'src/components/ClusterConfigManagement';
import FailoverManagement from 'src/components/FailoverManagement';
import ServerConsole from 'src/components/ServerConsole';
import Modal from 'src/components/Modal';
import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import ReplicasetEditModal from 'src/components/ReplicasetEditModal';
import ReplicasetList from 'src/components/ReplicasetList';
import ServerEditModal from 'src/components/ServerEditModal';
import ServerList from 'src/components/ServerList';
import { addSearchParams, getSearchParams } from 'src/misc/url';

import './Cluster.css';
import BootstrapPanel from "../../components/BootstrapPanel";

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

const filterReplicasetList = (replicasetList, rolesFilterValue, nameFilterValue) => {
  let filteredReplicasetList = replicasetList;

  if (rolesFilterValue) {
    filteredReplicasetList = filteredReplicasetList.filter(
      replicaset => replicaset.roles.includes(rolesFilterValue)
    )
  }

  if (nameFilterValue) {
    filteredReplicasetList = filteredReplicasetList.filter(
      replicaset => replicaset.uuid.startsWith(nameFilterValue) || replicaset.servers.some(
        server => server.uri.includes(nameFilterValue) || server.alias && server.alias.startsWith(nameFilterValue)
      )
    );
  }

  return filteredReplicasetList;
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

    return ! pageDataRequestStatus.loaded
      ? null
      : pageDataRequestStatus.error
        ? <PageDataErrorMessage error={pageDataRequestStatus.error}/>
        : this.renderContent();
  }

  renderContent = () => {
    const { clusterSelf, serverList, selectedServerUri, replicasetList, selectedReplicasetUuid,
      showBootstrapModal } = this.props;
    const { serverConsoleVisible, probeServerModalVisible, createReplicasetModalVisible,
      expelServerConfirmVisible, rolesFilterValue, nameFilterValue } = this.state;

    const joinServerModalVisible = !!selectedServerUri;
    const editReplicasetModalVisible = !!selectedReplicasetUuid;
    const unlinkedServers = this.getUnlinkedServers();
    const filteredReplicasetList = this.getFilteredReplicasetList();
    const canTestConfigBeApplied = !!serverList && serverList.length === 1 && serverList[0].status === 'unconfigured';

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

        <div className="pages-Cluster page-outer app-content">
          <div className="page-inner">
            <div className="container">
              {unlinkedServers.length
                ? (
                  <div className="tr-card-margin">
                    <div className="tr-pageCard-head">
                      <div className="tr-pageCard-header">
                        Unconfigured instances
                      </div>
                      <div className="tr-pageCard-buttons">
                        {this.renderProbeServerButtons()}
                      </div>
                    </div>
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
                : null}

              {clusterSelf.configured
                ? this.renderFailoverManagement()
                : null}

                <BootstrapPanel/>

              {replicasetList.length
                ? (
                  <div className="tr-card-margin pages-Cluster-replicasetList">
                    <div className="tr-pageCard-head">
                      <div className="tr-pageCard-header">
                        Replica sets
                      </div>
                      <div className="tr-pageCard-buttons">
                        {unlinkedServers.length
                          ? null
                          : this.renderProbeServerButtons()}
                      </div>
                    </div>

                    {replicasetList.length > 1
                      ? (
                        <div className="pages-Cluster-filter">
                          <div className="row form-inline">
                            <div className="col-auto form-group">
                              <label htmlFor="pages-Cluster-roles-filter">
                                Filter by role:
                              </label>
                              <select id="pages-Cluster-roles-filter"
                                className="form-control form-control-sm"
                                onChange={this.handleRolesFilterChange}
                                value={rolesFilterValue}
                              >
                                <option value="">Any role</option>
                                {clusterSelf.knownRoles.map(role => (
                                  <option value={role}>{role}</option>
                                ))}
                              </select>
                            </div>
                            <div className="col-auto form-group">
                              <label htmlFor="pages-Cluster-roles-filter">
                                Filter by uuid or server uri/alias:
                              </label>
                              <input type="text" id="pages-Cluster-roles-filter"
                                className="form-control form-control-sm"
                                onChange={this.handleNameFilterChange}
                                value={nameFilterValue} />
                            </div>
                            <div className="col-auto form-group align-self-right">
                              <button type="button" className="btn btn-success btn-sm"
                                onClick={this.handleResetFilterClick}
                              >
                                Reset form
                              </button>
                            </div>
                          </div>
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
                          createReplicaset={this.handleCreateReplicasetRequest} />
                      )
                      : (
                        <div className="trTable-noData">
                          No replicaset found
                        </div>
                      )}
                  </div>
                )
                : null}

              {false
                ? (
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
                )
                : null}
            </div>
            <div ref={this.setConsoleReserve} />
          </div>
        </div>
      </React.Fragment>
    );
  };

  renderFailoverManagement = () => {
    const { failover, changeFailover } = this.props;

    return (
      <FailoverManagement
        failoverEnabled={failover}
        onFailoverChangeRequest={changeFailover} />
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

  renderProbeServerButtons = () => {
    return (
      <div className="tr-cards-buttons">
        <button
          type="button"
          className="btn btn-light btn-sm"
          onClick={this.handleProbeServerRequest}
        >
          Probe server
        </button>
      </div>
    );
  };

  renderBootstrapVshardConfirmModal = () => {
    return (
      <Modal
        visible
        width={540}
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

  renderExpelServerConfirmModal = () => {
    const { expelServerConfirmDataSource } = this.state;

    return (
      <Modal
        visible
        width={540}
        onOk={this.handleExpelServerSubmitRequest}
        onCancel={this.handleExpelServerConfirmCloseRequest}
      >
        Do you really want to expel the server {expelServerConfirmDataSource.uri}?
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
    editReplicaset({
      uuid: replicaset.uuid,
      roles: replicaset.roles,
      master: replicaset.master,
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

  getFilteredReplicasetList = () => {
    const { rolesFilterValue, nameFilterValue } = this.state;
    const replicasetList = this.getReplicasetList();

    return replicasetList
      ? this.filterReplicasetList(replicasetList, rolesFilterValue, nameFilterValue)
      : null;
  };
}

export default Cluster;
