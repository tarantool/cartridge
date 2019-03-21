import React from 'react';
import PropTypes from 'prop-types';
import { css } from 'emotion';
import ServerListInstanceDetailsBtn from './ServerListInstanceDetailsBtn';

const styles = {
  button: css`
    color: #FF272C;
    display: inline-block;
    padding: 0;
    margin: 0 30px 0 0;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 12px;
    text-decoration: none;
    :last-child{
      margin: 0;
    }
    :hover{
      text-decoration: underline;
    }
  `,
};

class ServerListCellActions extends React.PureComponent {
  static propTypes = {
    record: PropTypes.object,
    consoleButton: PropTypes.bool,
    joinButton: PropTypes.bool,
    createButton: PropTypes.bool,
    instanceMenu: PropTypes.bool,
    onConsole: PropTypes.func,
    onJoin: PropTypes.func,
    onCreate: PropTypes.func,
    onExpel: PropTypes.func
  };

  handleConsoleClick = () => this.props.onConsole(this.props.record);

  handleJoinClick = () => this.props.onJoin(this.props.record);

  handleCreateClick = () => this.props.onCreate(this.props.record);

  handleExpelClick = () => this.props.onExpel(this.props.record);

  render() {
    const {
      record,
      consoleButton,
      joinButton,
      createButton,
      instanceMenu
    } = this.props;

    const buttonClassName = `${styles.button}`;

    return (
      <React.Fragment>
        {consoleButton
          ? (
            <button
              type="button"
              className={buttonClassName}
              onClick={this.handleConsoleClick}
            >
              Console
            </button>
          )
          : null}
        {joinButton
          ? (
            <button
              type="button"
              className={buttonClassName}
              onClick={this.handleJoinClick}
            >
              Join
            </button>
          )
          : null}
        {createButton
          ? (
            <button
              type="button"
              className={buttonClassName}
              onClick={this.handleCreateClick}
            >
              Create
            </button>
          )
          : null}
        {instanceMenu
          ? (
            <ServerListInstanceDetailsBtn
              className={buttonClassName}
              instanceUUID={record.uuid}
              onExpel={this.handleExpelClick}
            />
          )
          : null}
      </React.Fragment>
    );
  }
}

export default ServerListCellActions;
