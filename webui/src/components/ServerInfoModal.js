// @flow

import * as React from 'react'
import { connect } from 'react-redux'
import {
  Button,
  Modal,
  Tabbed
} from '@tarantool.io/ui-kit';
import { pageDidMount, resetPageState } from 'src/store/actions/clusterInstancePage.actions';
import { withRouter } from 'react-router-dom'
import ServerShortInfo from 'src/components/ServerShortInfo';
import ClusterInstanceSection from './ClusterInstanceSection'
import * as R from 'ramda';

type ServerInfoModalProps = {
  pageDidMount: ({ instanceUUID: string }) => void,
  resetPageState: () => void,
  alias: string,
  selfURI?: string,
  instanceUUID: string,
  labels: { name: string, value: string }[],
  message?: string,
  masterUUID: string,
  activeMasterUUID?: string,
  status: string,
  uri: string,
  match: { url: string },
  history: History,
}

type ServerInfoModalState = {
  selectedTab: ?string,
}


class ServerInfoModal extends React.Component<ServerInfoModalProps, ServerInfoModalState>{
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
      instanceUUID,
      selfURI,
      activeMasterUUID,
      masterUUID,
      message,
      status,
      uri
    } = this.props

    return (
      <Modal
        className='meta-test__ServerInfoModal'
        title='Server details'
        footerControls={[
          <Button onClick={this.onClose} text='Close' />
        ]}
        visible={true}
        onClose={this.close}
        thinBorders
        wide
      >
        <React.Fragment>
          <ServerShortInfo
            alias={alias}
            activeMaster={instanceUUID === activeMasterUUID}
            selfURI={selfURI}
            master={instanceUUID === masterUUID}
            message={message}
            status={status}
            uri={uri}
          />
          <Tabbed
            tabs={
              R.filter(R.identity, ServerInfoModal.tabsOrder).map(section => ({
                label: section[0].toUpperCase() + section.substring(1),
                content: (<ClusterInstanceSection sectionName={section}/>)
              }))
            }
          />
        </React.Fragment>
      </Modal>
    )
  }
}

const mapStateToProps = (state, props) => {
  const {
    alias,
    message,
    status,
    uri
  } = state.clusterPage.serverList.find(({ uuid }) => uuid === props.instanceUUID) || {};

  const {
    labels,
    masterUUID,
    activeMasterUUID
  } = state.clusterInstancePage;

  return {
    alias,
    selfURI: state.app.clusterSelf.uri,
    labels,
    message,
    masterUUID,
    activeMasterUUID,
    status,
    uri,
    instanceUUID: props.instanceUUID
  };
};

const mapDispatchToProps = {
  pageDidMount,
  resetPageState
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(ServerInfoModal));
