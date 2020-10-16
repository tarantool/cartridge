// @flow

import * as React from 'react'
import { connect } from 'react-redux'
import { css } from 'emotion';
import * as R from 'ramda';
import {
  Button,
  ControlsPanel,
  Modal,
  Tabbed,
  Text,
  colors
} from '@tarantool.io/ui-kit';
import { pageDidMount, resetPageState } from 'src/store/actions/clusterInstancePage.actions';
import { withRouter } from 'react-router-dom'
import ServerShortInfo from 'src/components/ServerShortInfo';
import ClusterInstanceSection from './ClusterInstanceSection'
import { ServerDropdown } from './ServerDropdown';

const flagStyles = css`
  display: inline-block;
  padding: 1px;
  background-color: ${colors.intentSuccessBorder};
  font-size: 11px;
  color: ${colors.dark65};
  text-transform: uppercase;
`;

const LeaderFlag = ({ state }: { state: string }) => (
  <Text variant='h5' tag='span' className={flagStyles}>Leader</Text>
);

type ServerInfoModalProps = {
  history: History,
  pageDidMount: ({ instanceUUID: string }) => void,
  resetPageState: () => void,
  alias: string,
  selfURI?: string,
  instanceUUID: string,
  replicasetUUID: string,
  labels: { name: string, value: string }[],
  message?: string,
  masterUUID: string,
  activeMasterUUID?: string,
  status: string,
  uri: string,
  match: { url: string },
  history: History,
  ro?: boolean
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
    // 'cartridge',
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
      history,
      replicasetUUID,
      instanceUUID,
      selfURI,
      activeMasterUUID,
      masterUUID,
      message,
      status,
      uri,
      ro
    } = this.props

    const activeMaster = instanceUUID === activeMasterUUID;
    const master = instanceUUID === masterUUID;

    return (
      <Modal
        className='meta-test__ServerInfoModal'
        title={<>
          {alias || instanceUUID}
          {(master || activeMaster) && (
            <LeaderFlag
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
        <ControlsPanel
          controls={[
            <Button
              intent='secondary'
              text='Promote'
              onClick={() => null}
              size='l'
            />,
            <ServerDropdown
              intent='secondary'
              activeMaster={activeMaster}
              replicasetUUID={replicasetUUID}
              uri={uri}
              history={history}
              uuid={instanceUUID}
              size='l'
            />
          ]}
        />
        <ServerShortInfo
          alias={alias}
          activeMaster={instanceUUID === activeMasterUUID}
          selfURI={selfURI}
          master={instanceUUID === masterUUID}
          message={message}
          status={status}
          uri={uri}
          ro={ro}
        />
        <Tabbed
          tabs={
            R.filter(R.identity, ServerInfoModal.tabsOrder).map(section => ({
              label: section[0].toUpperCase() + section.substring(1),
              content: (<ClusterInstanceSection sectionName={section}/>)
            }))
          }
        />
      </Modal>
    )
  }
}

const mapStateToProps = (state, props) => {
  const {
    alias,
    message,
    status,
    uri,
    ro,
    replicaset: { uuid: replicasetUUID }
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
    replicasetUUID,
    status,
    uri,
    instanceUUID: props.instanceUUID,
    ro
  };
};

const mapDispatchToProps = {
  pageDidMount,
  resetPageState
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(ServerInfoModal));
