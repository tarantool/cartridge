import PropTypes from 'prop-types';
import React from 'react';

import Button from 'src/components/Button';
import Icon from 'src/components/Icon';
import Modal from 'src/components/Modal';
import Upload from 'src/components/Upload';

import './ClusterConfigManagement.css';

const getUploadProps = createMessage => {
  return {
    name: 'file',
    action: process.env.REACT_APP_CONFIG_ENDPOINT,
    onChange(info) {
      if (info.file.status === 'done') {
        createMessage({
          content: { type: 'success', text: `${info.file.name} file uploaded successfully` }
        });
      } else if (info.file.status === 'error') {
        createMessage({
          content: { type: 'danger', text: info.file.response.err }
        });
      }
    },
  };
};

class ClusterConfigManagement extends React.PureComponent {
  constructor(props) {
    super(props);

    this.state = {
      confirmApplyTestConfigModalVisible: false,
    };

    this.uploadProps = getUploadProps(props.createMessage);
  }

  render() {
    const { canTestConfigBeApplied } = this.props;
    const { confirmApplyTestConfigModalVisible } = this.state;

    return (
      <div className="ClusterConfigManagement-outer">
        <div className="ClusterConfigManagement-inner">
          {confirmApplyTestConfigModalVisible
            ? this.renderApplyTestConfigConfirmModal()
            : null}
          <p>Current configuration can be downloaded <a href="/config">here</a>.</p>
          <p>You can upload a ZIP archive with config.yml and all necessary files:</p>
          <div className="ClusterConfigManagement-uploadBlock">
            <Upload {...this.uploadProps}>
              <Button>
                <Icon type="upload" /> Click to upload config
              </Button>
            </Upload>
          </div>
          {canTestConfigBeApplied
            ? this.renderApplyTestConfigSuggest()
            : null}
        </div>
      </div>
    );
  }

  renderApplyTestConfigConfirmModal = () => {
    return (
      <Modal
        visible
        width={540}
        onOk={this.confirmApplyTestConfig}
        onCancel={this.cancelApplyTestConfig}
      >
        Are you really want to apply test config?
      </Modal>
    );
  };

  renderApplyTestConfigSuggest = () => {
    const { isConfingApplying } = this.props;

    return (
      <React.Fragment>
        <p>You can also apply predefined test config:</p>
        <Button
          onClick={this.handleApplyTestConfigClick}
          disabled={isConfingApplying}
        >
          <Icon type="to-top" /> Click to apply config
        </Button>
      </React.Fragment>
    );
  };

  handleApplyTestConfigClick = () => {
    this.setState({ confirmApplyTestConfigModalVisible: true });
  };

  confirmApplyTestConfig = () => {
    const { applyTestConfig } = this.props;
    this.setState({ confirmApplyTestConfigModalVisible: false }, applyTestConfig);
  };

  cancelApplyTestConfig = () => {
    this.setState({ confirmApplyTestConfigModalVisible: false });
  };
}

ClusterConfigManagement.propTypes = {
  isConfingApplying: PropTypes.bool,
  canTestConfigBeApplied: PropTypes.bool.isRequired,
  applyTestConfig: PropTypes.func,
};

ClusterConfigManagement.defaultProps = {
  isConfingApplying: false,
};

export default ClusterConfigManagement;
