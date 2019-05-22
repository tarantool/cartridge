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
      authorizationFeature,
      authorizationEnabled,
      loading
    } = this.props;

    return authorizationFeature ?
      (
        <Button
          size='large'
          onClick={this.handleClick}
          disabled={loading}
          type={authorizationEnabled ? 'primary' : 'default'}
        >
          {`Auth: ${authorizationEnabled ? 'enabled' : 'disabled'}`}
        </Button>
      ) :
      null;
  }
}

const mapStateToProps = ({
  auth: {
    authorizationFeature,
    authorizationEnabled,
    loading
  }
}) => ({
  authorizationFeature,
  authorizationEnabled,
  loading
});

export default connect(mapStateToProps, { turnAuth })(AuthToggleButton);
