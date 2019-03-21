import PropTypes from 'prop-types';
import React from 'react';

import Modal from 'src/components/Modal';
import UploadButton from 'src/components/UploadButton';

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
      <div className="tr-card" style={{ marginTop: '20px' }}>
        <div className="tr-card-head">
          <div className="tr-card-header">
            Config management
          </div>
        </div>
        <div className="tr-card-content">
          {confirmApplyTestConfigModalVisible
            ? this.renderApplyTestConfigConfirmModal()
            : null}
          <p>Current configuration can be downloaded <a href={process.env.REACT_APP_CONFIG_ENDPOINT}>here</a>.</p>
          <div className="ClusterConfigManagement-uploadBlock">
            <UploadButton
              label="Click to upload config"
              onChange={this.handleUploadConfig} />
            {/*<Upload {...this.uploadProps}>
             <Button>
             <Icon type="upload" /> Click to upload config
             </Button>
             </Upload>*/}
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
        width={691}
        onOk={this.confirmApplyTestConfig}
        onCancel={this.cancelApplyTestConfig}
      >
        Do you really want to apply test config?
      </Modal>
    );
  };

  renderApplyTestConfigSuggest = () => {
    const { isConfingApplying } = this.props;

    return (
      <React.Fragment>
        <p>You can also apply predefined test config:</p>
        <button className="btn btn-primary"
          onClick={this.handleApplyTestConfigClick}
          disabled={isConfingApplying}
        >
          Click to apply config
        </button>
      </React.Fragment>
    );
  };

  handleUploadConfig = eventProps => {
    const { files } = eventProps;
    const { uploadConfig } = this.props;

    const data = new FormData();
    data.append('file', files[0]);

    uploadConfig({ data });
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
  uploadConfig: PropTypes.func.isRequired,
};

ClusterConfigManagement.defaultProps = {
  isConfingApplying: false,
};

export default ClusterConfigManagement;
