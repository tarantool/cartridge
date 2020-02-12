// @flow

import * as React from 'react'
import { connect } from 'react-redux'
import {
  Button,
  Modal,
  Tabbed,
  PopupFooter
} from '@tarantool.io/ui-kit';
import { pageDidMount, resetPageState } from 'src/store/actions/clusterInstancePage.actions';
import isEqual from 'lodash/isEqual';
import { defaultMemoize, createSelectorCreator } from 'reselect';
import { withRouter } from 'react-router-dom'
import ServerShortInfo from 'src/components/ServerShortInfo';
import ClusterInstanceSection from './ClusterInstanceSection'
import * as R from 'ramda';

type ServerInfoModalProps = {
  pageDidMount: ({ instanceUUID: string }) => void,
  resetPageState: () => void,
  alias: string,
  instanceUUID: string,
  labels: { name: string, value: string }[],
  message?: string,
  masterUUID: string,
  activeMasterUUID?: string,
  roles: string,
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
      activeMasterUUID,
      masterUUID,
      message,
      status,
      uri
    } = this.props
    console.log(ServerInfoModal.tabsOrder);
    
    return (
      <Modal
        className='meta-test__ServerInfoModal'
        title='Server details'
        visible={true}
        onClose={this.close}
        wide
      >
        <React.Fragment>
          <ServerShortInfo
            alias={alias}
            activeMaster={instanceUUID === activeMasterUUID}
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
          <PopupFooter
            controls={[
              <Button intent={'base'} text={'Close'} onClick={this.close} />
            ]}
          />
        </React.Fragment>
      </Modal>
    )
  }
}

const getSectionsNames = state => Object.keys(state.clusterInstancePage.boxinfo || {});

const selectSectionsNames = createSelectorCreator(
  defaultMemoize,
  isEqual
)(
  getSectionsNames,
  sectionsNames => sectionsNames
)

const mapStateToProps = (state, props) => {
  const {
    alias,
    labels,
    message,
    masterUUID,
    activeMasterUUID,
    roles = [],
    status,
    uri
  } = state.clusterInstancePage;

  return {
    alias,
    labels,
    message,
    masterUUID,
    activeMasterUUID,
    roles: roles.join(', '),
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
