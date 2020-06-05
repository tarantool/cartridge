// @flow
import React from 'react';
import { css } from 'react-emotion';
import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import { Modal, Tabbed } from '@tarantool.io/ui-kit';
import JoinReplicasetForm from 'src/components/JoinReplicasetForm';
import CreateReplicasetForm from 'src/components/CreateReplicasetForm';
import { addSearchParams } from 'src/misc/url';
import type {
  Server,
  Role,
  Replicaset,
  VshardGroup
} from 'src/generated/graphql-typing';
import type { CreateReplicasetArgs } from 'src/store/request/clusterPage.requests';
import {
  createReplicaset,
  joinServer,
  setModalFilter
} from 'src/store/actions/clusterPage.actions';
import { filterModalReplicasetListSelector } from 'src/store/selectors/clusterPage';

const styles = {
  tabContent: css`
    padding: 24px 0 0;
  `
}

type ConfigureServerModalProps = {
  createReplicaset: () => void,
  filter?: string,
  filteredReplicasetList?: Replicaset[],
  knownRoles?: Role[],
  loading?:? boolean,
  vshard_groups?: VshardGroup[],
  replicasetList?: Replicaset[],
  serverList?: Server[],
  selectedServerUri?: string,
  history: History,
  location: Location,
  setModalFilter: Function,
  joinServer: Function,
  createReplicaset: Function,
  selfURI?: string
}

class ConfigureServerModal extends React.Component<ConfigureServerModalProps> {
  render() {
    const {
      filter,
      filteredReplicasetList,
      knownRoles,
      loading,
      vshard_groups,
      replicasetList,
      serverList,
      selectedServerUri,
      setModalFilter,
      selfURI
    } = this.props;

    const selectedServers = (
      serverList && serverList.filter(server => {
        return (selectedServerUri instanceof Array)
          ? selectedServerUri.includes(server.uri)
          : selectedServerUri === server.uri;
      })
    ) || [];

    const tabs = [
      {
        label: 'Create Replica Set',
        content: (
          <div className={styles.tabContent}>
            <CreateReplicasetForm
              selectedServers={selectedServers}
              vshard_groups={vshard_groups}
              knownRoles={knownRoles}
              onSubmit={this.handleCreateReplicasetSubmit}
              onCancel={this.handleClose}
              selfURI={selfURI}
            />
          </div>
        )
      }
    ];

    if (replicasetList && replicasetList.length) {
      tabs.push({
        label: 'Join Replica Set',
        content: (
          <div className={styles.tabContent}>
            <JoinReplicasetForm
              filter={filter || ''}
              onCancel={this.handleClose}
              onSubmit={this.handleJoinServerSubmit}
              replicasetList={replicasetList}
              filteredReplicasetList={filteredReplicasetList}
              selectedServers={selectedServers}
              knownRoles={knownRoles}
              setFilter={setModalFilter}
              selfURI={selfURI}
            />
          </div>
        )
      })
    }

    return (
      <Modal
        className='meta-test__ConfigureServerModal'
        title='Configure server'
        visible={!!selectedServerUri}
        loading={loading}
        onClose={this.handleClose}
        wide
      >
        <Tabbed tabs={tabs} />
      </Modal>
    );
  }

  handleCreateReplicasetSubmit = (formData: CreateReplicasetArgs) => {
    this.props.createReplicaset(formData);
    this.handleClose();
  };

  handleClose = () => {
    const { history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { s: null })
    });
  }

  handleJoinServerSubmit = (data: { uri: string, replicasetUuid: string}) => {
    const { joinServer, history, location } = this.props;
    history.push({
      search: addSearchParams(location.search, { s: null })
    });
    joinServer(data.uri, data.replicasetUuid);
  };
};

const mapStateToProps = state => {
  const {
    app: {
      clusterSelf: {
        knownRoles,
        vshard_groups,
        uri: selfURI
      }
    },
    clusterPage: {
      modalReplicasetFilter,
      pageDataRequestStatus,
      replicasetList,
      selectedServerUri,
      serverList
    }
  } = state;

  return {
    filter: modalReplicasetFilter,
    filteredReplicasetList: modalReplicasetFilter
      ? filterModalReplicasetListSelector(state)
      : replicasetList,
    knownRoles,
    vshard_groups,
    replicasetList,
    selectedServerUri,
    serverList,
    selfURI,
    loading: !pageDataRequestStatus.loaded || pageDataRequestStatus.loading
  };
};

const mapDispatchToProps = {
  createReplicaset,
  joinServer,
  setModalFilter
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(ConfigureServerModal));
