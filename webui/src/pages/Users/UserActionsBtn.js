import React from 'react';
import PropTypes from 'prop-types';
import { Dropdown, Menu } from 'antd';
import Button from 'src/components/Button';
import { css } from 'emotion';

const styles = {
  menuItemDanger: css`
    color: #FF272C !important;
  `
};

class UserActionsBtn extends React.PureComponent {
  static propTypes = {
    className: PropTypes.string,
    allowEditing: PropTypes.bool,
    allowRemoving: PropTypes.bool,
    username: PropTypes.string,
  };

  handleEditUser = e => {
    e.domEvent.stopPropagation();
    this.props.onEditUser(this.props.username);
  }

  handleRemoveUser = e => {
    e.domEvent.stopPropagation();
    this.props.onRemoveUser(this.props.username);
  }

  stopPropagation = e => e.stopPropagation();

  render() {
    const { allowEditing, allowRemoving, className } = this.props;

    const menu = (
      <Menu>
        {allowEditing && <Menu.Item onClick={this.handleEditUser}>Edit</Menu.Item>}
        {allowEditing && allowRemoving && <Menu.Divider />}
        {allowRemoving && <Menu.Item onClick={this.handleRemoveUser} className={styles.menuItemDanger}>Remove</Menu.Item>}
      </Menu>
    );

    return (
      <Dropdown overlay={menu} trigger='click' placement="bottomRight" onClick={this.stopPropagation}>
        <Button
          className={className}
          icon="ellipsis"
        />
      </Dropdown>
    );
  }
}

export default UserActionsBtn;
