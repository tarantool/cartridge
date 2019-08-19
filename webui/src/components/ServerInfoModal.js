// @flow

import * as React from 'react'
import Modal from './Modal'
import { connect } from 'react-redux'
import { expelServer, hideExpelModal } from '../store/actions/clusterPage.actions';
import { selectServerByUri } from '../store/selectors/clusterPage';
import { formatServerName } from '../misc/server';
import { css } from 'react-emotion'
import Text from './Text';
import { pageDidMount, resetPageState } from 'src/store/actions/clusterInstancePage.actions';
import isEqual from 'lodash/isEqual';
import { defaultMemoize, createSelectorCreator } from 'reselect';
import { withRouter } from 'react-router-dom'
import Tabbed from 'src/components/Tabbed';
import ServerShortInfo from 'src/components/ServerShortInfo';
import ClusterInstanceSection from './ClusterInstanceSection'
import Button from './Button';

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
  subsections: string[],
  match: { url: string },
  history: Object,
}

type ServerInfoModalState = {
  selectedTab: ?string,
}


class ServerInfoModal extends React.Component<ServerInfoModalProps, ServerInfoModalState>{
  state = {
    selectedTab: null,
  }

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
      subsections,
      history,
      alias,
      instanceUUID,
      activeMasterUUID,
      message,
      status,
      uri,
    } = this.props
    return (
      <Modal
        title={'Detail server'}
        visible={true}
        onClose={this.close}
        wide
      >
        <React.Fragment>
          <ServerShortInfo
            alias={alias}
            master={instanceUUID === activeMasterUUID}
            message={message}
            status={status}
            uri={uri}
          />
          <Tabbed
            tabs={
              subsections.map(section => ({
                label: section,
                content: (<ClusterInstanceSection sectionName={section} />)
              }))
            }
          />
          <div className={css`display: flex; justify-content: flex-end;`}>
            <Button intent={'base'} text={'Close'} onClick={this.close} />
          </div>
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
    subsections: selectSectionsNames(state),
    instanceUUID: props.instanceUUID
  };
};

const mapDispatchToProps = {
  pageDidMount,
  resetPageState
};

export default connect(mapStateToProps, mapDispatchToProps)(withRouter(ServerInfoModal));
