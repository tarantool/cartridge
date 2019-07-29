import React from 'react';
import PropTypes from 'prop-types';
import { css } from 'emotion';
import { Link } from 'react-router-dom';
import { Button, Dropdown, Menu } from 'antd';
import { PROJECT_NAME } from 'src/constants';

const styles = {
  // TODO: Move global constants from variables.scss
  menuItemDanger: css`
    color: #FF272C !important;
  `
};

class ServerListInstanceDetailsBtn extends React.PureComponent {
  static propTypes = {
    instanceUUID: PropTypes.string,
    onExpel: PropTypes.func,
    className: PropTypes.string
  };

  render() {
    const {
      className,
      instanceUUID,
      onExpel
    } = this.props;

    const menu = (
      <Menu>
        {!!instanceUUID && (
          <Menu.Item>
            <Link to={`/${PROJECT_NAME}/instance/${instanceUUID}`}>Details</Link>
          </Menu.Item>
        )}
        <Menu.Divider />
        <Menu.Item className={styles.menuItemDanger} onClick={onExpel}>Expel</Menu.Item>
      </Menu>
    );

    return (
      <Dropdown overlay={menu} trigger='click' placement="bottomRight">
        <Button
          className={className}
          icon="ellipsis"
        />
      </Dropdown>
    );
  }
}

export default ServerListInstanceDetailsBtn;
