import { connect } from 'react-redux';
import ConfigManagement from './ConfigManagement';

const mapStateToProps = state => {
  const {
    clusterPage: {
      uploadConfigRequestStatus
    }
  } = state;

  return {
    uploadConfigRequestStatus
  };
};

export default connect(mapStateToProps)(ConfigManagement);
