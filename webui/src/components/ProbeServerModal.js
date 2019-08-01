// @flow
import React from 'react';
import { connect } from 'react-redux';
import { probeServer } from 'src/store/actions/clusterPage.actions';
import type { ProbeServerActionCreator } from 'src/store/actions/clusterPage.actions';
import CommonItemEditModal, { type CommonItemEditModalField } from 'src/components/CommonItemEditModal';

const prepareFields = (): CommonItemEditModalField[] => {
  return [
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
    }
  ];
};

const getServerDefaultDataSource = () => {
  return {
    uuid: null,
    uri: '',
    replicasetUuid: null
  };
};

type ProbeServerModalProps = {
  error?: string,
  isLoading?: boolean,
  isSaving?: boolean,
  submitStatusMessage?: string,
  probeServer: ProbeServerActionCreator,
  onRequestClose: () => void
};

class ProbeServerModal extends React.PureComponent<ProbeServerModalProps> {
  static defaultProps = {
    isLoading: false,
    isSaving: false
  };

  render() {
    const {
      error,
      isLoading,
      isSaving,
      submitStatusMessage,
      onRequestClose
    } = this.props;

    const fields = isLoading ? null : prepareFields();
    const dataSource = isLoading ? null : getServerDefaultDataSource();

    return (
      <CommonItemEditModal
        title='Probe server'
        isLoading={isLoading}
        isSaving={isSaving}
        shouldCreateItem
        fields={fields}
        hideLabels
        dataSource={dataSource}
        errorMessage={error}
        submitStatusMessage={submitStatusMessage}
        onSubmit={this.handleSubmit}
        onRequestClose={onRequestClose}
      />
    );
  }

  handleSubmit = ({ uri }) => {
    this.props.probeServer(uri);
  };
}

const mapStateToProps = state => ({
  error: state.clusterPage.probeServerError
});

const mapDispatchToProps = {
  probeServer
};

export default connect(mapStateToProps, mapDispatchToProps)(ProbeServerModal);
