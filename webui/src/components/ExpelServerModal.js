// @flow
import React from 'react';
import { connect } from 'react-redux';
import { ConfirmModal, Text } from '@tarantool.io/ui-kit';

import { formatServerName } from '../misc/server';
import { expelServer, hideExpelModal } from '../store/actions/clusterPage.actions';
import { selectServerByUri } from '../store/selectors/clusterPage';

type ExpelServerModalProps = {
  expelModal: ?string,
  dispatch: Function,
  serverInfo: ?Object,
};

const ExpelServerModal = ({ dispatch, expelModal, serverInfo }: ExpelServerModalProps) => (
  <ConfirmModal
    className="meta-test__ExpelServerModal"
    title="Expel server"
    visible={!!expelModal}
    confirmText="Expel"
    onConfirm={() => dispatch(expelServer(serverInfo))}
    onCancel={() => dispatch(hideExpelModal())}
  >
    <Text tag="p">Do you really want to expel the server {serverInfo ? formatServerName(serverInfo) : ''}?</Text>
  </ConfirmModal>
);

export default connect((state) => {
  const expelModal = state.ui.expelModal;

  return {
    expelModal,
    serverInfo: expelModal ? selectServerByUri(state, expelModal) : null,
  };
})(ExpelServerModal);
