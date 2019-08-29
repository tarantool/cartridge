// @flow

import * as React from 'react'
import { ConfirmModal } from './Modal'
import { connect } from 'react-redux'
import Alert from 'src/components/Alert';
import { expelServer, hideExpelModal } from '../store/actions/clusterPage.actions';
import { selectServerByUri } from '../store/selectors/clusterPage';
import { formatServerName } from '../misc/server';
import { css } from 'react-emotion'
import Text from './Text';

class ExpelServerModal extends React.Component<{expelModal: ?string, dispatch: Function, serverInfo: ?Object}>{
  render() {
    const {
      expelModal,
      serverInfo,
      error
    } = this.props
    return (
      <ConfirmModal
        title={'Expel server'}
        visible={!!expelModal}
        confirmText={'Expel'}
        onConfirm={() => {this.props.dispatch(expelServer(serverInfo))}}
        onCancel={() => {this.props.dispatch(hideExpelModal())}}
      >
        <div className={css`padding: 16px`}>
          <p className={css``}>
            <Text variant={'basic'}>
              Do you really want to expel the server {serverInfo ? formatServerName(serverInfo) : ''}?
            </Text>
          </p>
          {error ? (
            <Alert type="error" >
              <Text variant="basic">{error}</Text>
            </Alert>
          ) : null}
        </div>
      </ConfirmModal>
    )
  }
}


export default connect(state => {
  const expelModal = state.ui.expelModal
  const error = state.ui.expelError
  return {
    expelModal,
    error,
    serverInfo: expelModal ? selectServerByUri(state, expelModal) : null
  }
})(ExpelServerModal)
