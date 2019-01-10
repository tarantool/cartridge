import React from 'react';

import SettingsIcon from 'src/icons/Settings';
import UserLogoutIcon from 'src/icons/UserLogout';
import Link from 'src/components/Link';
import NavLink from 'src/components/NavLink';

import './TopMenu.css';

class TopMenu extends React.Component {
  render() {
    const { pages } = this.props;

    return (
      <div className="TopMenu-outer app-menu">
        <div className="TopMenu-inner container">
          <div className="TopMenu-linkList">
            {pages.map(page => {
              return (
                <div
                  key={page.url}
                  className="TopMenu-menuItem"
                >
                  <NavLink
                    to={page.url}
                    exact={page.exact}
                    className="TopMenu-link"
                    activeClassName="TopMenu-link--active"
                  >
                    {page.name}
                  </NavLink>
                </div>
              );
            })}
            <div className="TopMenu-menuItem">
              <a
                href="/docs/index.html"
                target="_blank"
                className="TopMenu-link TopMenu-docsLink"
              >
                Docs
              </a>
            </div>
          </div>
          <div className="TopMenu-optionList">
            <Link
              className="TopMenu-option TopMenu-optionLink TopMenu-option-settings"
              to="/settings/users"
            >
              <SettingsIcon />
            </Link>
            <Link
              className="TopMenu-option TopMenu-optionLink TopMenu-option-logout"
              to="/"
              onClick={this.handleLogoutClick}
            >
              <UserLogoutIcon />
            </Link>
          </div>
        </div>
      </div>
    );
  }

  handleLogoutClick = () => {
    const { logout } = this.props;
    logout();
  };
}

export default TopMenu;
