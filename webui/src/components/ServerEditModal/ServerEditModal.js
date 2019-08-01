// @flow
import React from 'react';
import { defaultMemoize } from 'reselect';
import type {
  Replicaset,
  Server
} from 'src/generated/graphql-typing';
import CommonItemEditModal, { type CommonItemEditModalField } from 'src/components/CommonItemEditModal';

const prepareFields = (replicasetList: Replicaset[] = []): CommonItemEditModalField[] => {
  return [
    {
      key: 'uuid',
      hidden: true
    },
    {
      key: 'uri',
      type: 'input',
      title: 'URI',
      customProps: {
        edit: {
          hidden: true
        }
      },
      placeholder: 'Server URI, e.g. localhost:3301'
    },
    {
      key: 'replicasetUuid',
      title: 'Replicaset',
      type: 'optionGroup',
      customProps: {
        create: {
          hidden: true
        }
      },
      options: replicasetList.map(replicaset => {
        const aliasText = replicaset.servers.map(server => server.alias || server.uuid.slice(0, 8)).join(', ');
        const uuidText = `[${replicaset.uuid.slice(0, 8)}]`;
        const label = `${uuidText} ${aliasText}`;

        return {
          key: replicaset.uuid,
          label
        };
      })
    }
  ];
};

const getServerDataSource = (server: Server) => {
  return {
    ...server,
    replicasetUuid: server.replicaset
      ? server.replicaset.uuid
      : null
  };
};

type ServerEditModalProps = {
  isLoading?: boolean,
  isSaving?: boolean,
  serverNotFound?: boolean,
  server?: Server,
  replicasetList: Replicaset[],
  submitStatusMessage?: string,
  onSubmit: () => void,
  onRequestClose: () => void
};

class ServerEditModal extends React.PureComponent<ServerEditModalProps> {
  prepareFields = defaultMemoize(prepareFields);

  static defaultProps = {
    isLoading: false,
    isSaving: false,
    serverNotFound: false
  };

  render() {
    const {
      isLoading,
      isSaving,
      serverNotFound,
      server,
      submitStatusMessage,
      onSubmit,
      onRequestClose
    } = this.props;

    const fields = isLoading ? null : this.getFields();
    const dataSource = isLoading || serverNotFound || !server ? null : getServerDataSource(server);

    return (
      <CommonItemEditModal
        title='Join server'
        isLoading={isLoading}
        isSaving={isSaving}
        itemNotFound={serverNotFound}
        fields={fields}
        hideLabels
        dataSource={dataSource}
        submitStatusMessage={submitStatusMessage}
        onSubmit={onSubmit}
        onRequestClose={onRequestClose}
      />
    );
  }

  getFields = () => {
    const { replicasetList } = this.props;
    return this.prepareFields(replicasetList);
  };
}

export default ServerEditModal;
