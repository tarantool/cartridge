import React from 'react';
import { connect } from 'react-redux';
import Button from 'src/components/Button';
import { css } from 'emotion';
import { logOut } from 'src/store/actions/auth.actions';
import { ModalLogInForm } from 'src/components/LogInForm';

const styles = {
  box: css`
    display: flex;
    justify-content: flex-end;
    align-items: center;
    width: 200px;
    margin: 13px 30px 0 auto;
  `,
  userName: css`
    margin-right: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: white;
  `,
  button: css`
    flex-shrink: 0;
  `
};

class HeaderAuthControl extends React.Component {
  state = {
    authModalOpened: false
  };

  static getDerivedStateFromProps(props, state) {
    if (props.authorized && state.authModalOpened) {
      return { authModalOpened: false };
    }

    return null;
  }

  showAuthModal = () => this.setState({ authModalOpened: true });
  hideAuthModal = () => this.setState({ authModalOpened: false });

  render() {
    const {
      authorizationFeature,
      authorizationEnabled,
      username,
      authorized,
      logOut
    } = this.props;

    if (!authorizationFeature)
      return null;

    if (authorizationEnabled & !authorized)
      return null;

    return (
      <div className={styles.box}>
        <span class={styles.userName}>{username}</span>
        {
          authorized
            ? <Button
              className={styles.button}
              size="small"
              shape="circle"
              onClick={logOut}
              icon="logout"
              title="Log out"
            />
            : <Button
              className={styles.button}
              size="small"
              onClick={this.showAuthModal}
              icon="user"
              title="Log in"
              text="Log in"
            >
              Log in
            </Button>
        }
        <ModalLogInForm
          visible={this.state.authModalOpened}
          onCancel={this.hideAuthModal}
        />
      </div>
    );
  }
}

const mapStateToProps = ({
  auth: {
    authorizationFeature,
    authorizationEnabled,
    username,
    authorized,
  }
}) => ({
  authorizationFeature,
  authorizationEnabled,
  username,
  authorized,
});

export default connect(mapStateToProps, { logOut })(HeaderAuthControl);
