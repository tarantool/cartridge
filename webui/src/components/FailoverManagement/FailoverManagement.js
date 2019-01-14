import PropTypes from 'prop-types';
import React from 'react';

import './FailoverManagement.css';

class FailoverManagement extends React.PureComponent {
  render() {
    const { failoverEnabled } = this.props;
    const changeButtonText = failoverEnabled ? 'Disable' : 'Enable';
    const failoverStatuText  = failoverEnabled ? 'enabled' : 'disabled';

    return (
      <div className="FailoverManagement-outer tr-card tr-card-margin">
        <div className="tr-card-head">
          <div className="tr-card-header">
            Failover
          </div>
        </div>
        <div className="tr-card-content">
          <p>When enabled, every storage starts monitoring instances status. When user-specified master goes down, a replica with lowest UUID takes his place. When user-specified master returns online, their roles are restored.</p>
          <p>Failover is <b>{failoverStatuText}</b></p>
          <button className="btn btn-primary"
            onClick={this.handleChangeFailoverClick}
          >
            {changeButtonText}
          </button>
        </div>
      </div>
    );
  }

  handleChangeFailoverClick = () => {
    const { failoverEnabled, onFailoverChangeRequest } = this.props;
    onFailoverChangeRequest({ enabled: ! failoverEnabled });
  };
}

FailoverManagement.propTypes = {
  failoverEnabled: PropTypes.bool.isRequired,
  onFailoverChangeRequest: PropTypes.func.isRequired,
};

export default FailoverManagement;
