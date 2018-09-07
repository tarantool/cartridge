import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import CommonItemEditModal from 'src/components/CommonItemEditModal';

import './ServerEditModal.css';

const prepareFields = (replicasetList = []) => {
  return [
    {
      key: 'uuid',
      hidden: true,
    },
    {
      key: 'uri',
      type: 'input',
      title: 'URI',
      customProps: {
        edit: {
          hidden: true,
        },
      },
    },
    {
      key: 'replicasetUuid',
      title: 'Replicaset',
      type: 'optionGroup',
      customProps: {
        create: {
          hidden: true,
        },
      },
      options: replicasetList.map(replicaset => {
        const aliasText = replicaset.servers.map(server => server.alias || server.uuid.slice(0, 8)).join(', ');
        const uuidText = `[${replicaset.uuid.slice(0, 8)}]`;
        const label = `${uuidText} ${aliasText}`;

        return {
          key: replicaset.uuid,
          label,
        };
      }),
    },
  ];
};

const getServerDefaultDataSource = () => {
  return {
    uuid: null,
    uri: '',
    replicasetUuid: null,
  };
};

const getServerDataSource = server => {
  return {
    ...server,
    replicasetUuid: server.replicaset
      ? server.replicaset.uuid
      : null,
  };
};

class ServerEditModal extends React.PureComponent {
  constructor(props) {
    super(props);

    this.prepareFields = defaultMemoize(prepareFields);
  }

  render() {
    const { isLoading, isSaving, serverNotFound, shouldCreateServer, server, submitStatusMessage, onSubmit,
      onRequestClose } = this.props;

    const fields = isLoading ? null : this.getFields();
    const dataSource = isLoading
      ? null
      : shouldCreateServer ? getServerDefaultDataSource() : getServerDataSource(server);

    return (
      <CommonItemEditModal
        title={['Probe server', 'Join server']}
        isLoading={isLoading}
        isSaving={isSaving}
        itemNotFound={serverNotFound}
        shouldCreateItem={shouldCreateServer}
        fields={fields}
        hideLabels
        dataSource={dataSource}
        submitStatusMessage={submitStatusMessage}
        onSubmit={onSubmit}
        onRequestClose={onRequestClose} />
    );
  }

  getFields = () => {
    const { replicasetList } = this.props;
    return this.prepareFields(replicasetList);
  };
}

ServerEditModal.propTypes = {
  isLoading: PropTypes.bool,
  isSaving: PropTypes.bool,
  serverNotFound: PropTypes.bool,
  shouldCreateServer: PropTypes.bool,
  server: PropTypes.shape({
    uuid: PropTypes.string.isRequired,
    uri: PropTypes.string.isRequired,
    replicasetUuid: PropTypes.arrayOf(PropTypes.string),
  }),
  replicasetList: PropTypes.arrayOf(PropTypes.shape({
    uuid: PropTypes.string.isRequired,
    roles: PropTypes.arrayOf(PropTypes.string).isRequired,
  })),
  submitStatusMessage: PropTypes.string,
  onSubmit: PropTypes.func.isRequired,
  onRequestClose: PropTypes.func.isRequired,
};

ServerEditModal.defaultProps = {
  isLoading: false,
  isSaving: false,
  serverNotFound: false,
  shouldCreateServer: false,
};

export default ServerEditModal;
