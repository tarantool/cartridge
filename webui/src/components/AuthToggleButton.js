import React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import { turnAuth } from 'src/store/actions/auth.actions';

class AuthToggleButton extends React.Component {
  handleClick = () => {
    this.props.turnAuth(!this.props.authorizationEnabled);
  };

  render() {
    const {
      implements_check_password,
      authorizationEnabled,
      fetchingAuth
    } = this.props;

    return implements_check_password ?
      (
        <Button
          size='large'
          onClick={this.handleClick}
          disabled={fetchingAuth}
          type={authorizationEnabled ? 'primary' : 'default'}
        >
          {`Auth: ${authorizationEnabled ? 'enabled' : 'disabled'}`}
        </Button>
      ) :
      null;
  }
}

const mapStateToProps = ({
  app: {
    authParams: {
      implements_check_password
    }
  },
  auth: {
    authorizationEnabled
  },
  ui: {
    fetchingAuth
  }
}) => ({
  implements_check_password,
  authorizationEnabled,
  fetchingAuth
});

export default connect(mapStateToProps, { turnAuth })(AuthToggleButton);
