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
  `
};

class ServerListCellActions extends React.Component {
  static propTypes = {
    record: PropTypes.object,
    joinButton: PropTypes.bool,
    createButton: PropTypes.bool,
    instanceMenu: PropTypes.bool,
    onJoin: PropTypes.func,
    onCreate: PropTypes.func,
    onExpel: PropTypes.func
  };

  handleJoinClick = () => this.props.onJoin(this.props.record);

  handleCreateClick = () => this.props.onCreate(this.props.record);

  handleExpelClick = () => this.props.onExpel(this.props.record);

  render() {
    const {
      record,
      joinButton,
      createButton,
      instanceMenu
    } = this.props;

    const buttonClassName = `${styles.button}`;

    return (
      <React.Fragment>
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
