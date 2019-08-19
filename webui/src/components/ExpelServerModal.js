// @flow

import * as React from 'react'
import { ConfirmModal } from './Modal'
import { connect } from 'react-redux'
import { expelServer, hideExpelModal } from '../store/actions/clusterPage.actions';
import { selectServerByUri } from '../store/selectors/clusterPage';
import { formatServerName } from '../misc/server';
import { css } from 'react-emotion'
import Text from './Text';

class ExpelServerModal extends React.Component<{expelModal: ?string, dispatch: Function, serverInfo: ?Object}>{
  render() {
    const {
      expelModal,
      serverInfo
    } = this.props
    return (
      <ConfirmModal
        title={'Expel server'}
        visible={!!expelModal}
        confirmText={'Expel'}
        onConfirm={() => {this.props.dispatch(expelServer(serverInfo))}}
        onCancel={() => {this.props.dispatch(hideExpelModal())}}
      >
        <p className={css`padding: 16px`}>
          <Text variant={'basic'}>
            Do you really want to expel the server {serverInfo ? formatServerName(serverInfo) : ''}?
          </Text>
        </p>
      </ConfirmModal>
    )
  }
}


export default connect(state => {
  const expelModal = state.ui.expelModal
  return {
    expelModal,
    serverInfo: expelModal ? selectServerByUri(state, expelModal) : null
  }
})(ExpelServerModal)
