import React from 'react';
import { defaultMemoize } from 'reselect';

import { getServerName } from 'src/app/misc';
import AppBottomConsole from 'src/components/AppBottomConsole';
import ServerConsole from 'src/components/ServerConsole';
import Modal from 'src/components/Modal';
import PageDataErrorMessage from 'src/components/PageDataErrorMessage';
import ReplicasetEditModal from 'src/components/ReplicasetEditModal';
import ReplicasetList from 'src/components/ReplicasetList';
import ServerEditModal from 'src/components/ServerEditModal';
import FailoverButton from 'src/components/FailoverButton';
import ServerList from 'src/components/ServerList';
import { addSearchParams, getSearchParams } from 'src/misc/url';
import {Title, FilterInput} from '../../components/styled';
import ClusterConfigManagement from 'src/components/ClusterConfigManagement';

import './Cluster.css';
import BootstrapPanel from "../../components/BootstrapPanel";
import {Button, Icon} from 'antd'
import {css} from 'react-emotion';

import * as R from 'ramda';

const styles = {
  buttons: css`
    display: flex;
    margin-right: 16px;
  `,
  button: css`
    display: block;
    margin-right: 25px;
    :last-child{
      margin-right: 0px;
    }
  `,
  clusterFilter: css`
    margin-bottom: 20px;
    padding-left: 5px;
  `,
  clusterInputContainer: css`
    width: 400px;
    max-width: 100%;
    height: 30px;
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
  const tokenizedFilter = filter.split(' ').map(x => x.trim()).filter(x => !!x);

  const searchableList = replicasetList.map(r => {
    return {
      ...r,
      searchString: `${r.roles.join(' ')} ${r.servers.map(s => `${s.uri} ${s.alias||''}`).join(' ')}`,
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

    return ! pageDataRequestStatus.loaded
      ? null
      : pageDataRequestStatus.error
        ? <PageDataErrorMessage error={pageDataRequestStatus.error}/>
        : this.renderContent();
  }

  renderContent = () => {
    const { clusterSelf, selectedServerUri, replicasetList, selectedReplicasetUuid,
      showBootstrapModal } = this.props;
    const { serverConsoleVisible, probeServerModalVisible, createReplicasetModalVisible,
      expelServerConfirmVisible } = this.state;

    const joinServerModalVisible = !!selectedServerUri;
    const editReplicasetModalVisible = !!selectedReplicasetUuid;
    const unlinkedServers = this.getUnlinkedServers();
    const filteredReplicasetList = this.getFilteredReplicasetList();

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
            <div className="" >
              {unlinkedServers.length
                ? (
                  <div className="tr-card-margin">
                    <div className="tr-pageCard-head">
                      <div className="tr-pageCard-header">
                        <Title>Unconfigured instances</Title>
                      </div>
                      <div className="tr-pageCard-buttons">
                        {this.renderServerButtons()}
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

                  <BootstrapPanel/>

              {replicasetList.length
                ? (
                  <div className="tr-card-margin pages-Cluster-replicasetList">
                    <div className="tr-pageCard-head">
                      <div className="tr-pageCard-header">
                        <Title>Replica sets</Title>
                      </div>
                      <div className="tr-pageCard-buttons">
                        {unlinkedServers.length
                          ? null
                          : this.renderServerButtons()}
                      </div>
                    </div>

                    {replicasetList.length > 1
                      ? (
                        <div className={styles.clusterFilter}>
                            <div className={styles.clusterInputContainer}>
                              <FilterInput
                                prefix={<Icon type="search" />}
                                type={"text"}
                                placeholder={'Filter by uri, uuid, role or alias'}
                                value={this.state.filter}
                                onChange={this.handleFilterChange}
                              />
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

                <ClusterConfigManagement
                  uploadConfig={this.uploadConfig}
                  canTestConfigBeApplied={false}
                  applyTestConfig={this.applyTestConfig} />
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

  renderServerButtons = () => {
    return (
      <div className={styles.buttons}>
        <div className={styles.button}><FailoverButton size={'large'} /></div>
        <div className={styles.button}>
          <Button

            size={'large'}
            onClick={this.handleProbeServerRequest}
          >
            Probe server
          </Button>
        </div>
      </div>
    );
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
    const { filter } = this.state;
    const replicasetList = this.getReplicasetList();

    return replicasetList
      ? this.filterReplicasetList(replicasetList, filter)
      : null;
  };
}

export default Cluster;
