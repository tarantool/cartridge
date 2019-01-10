import React from 'react';

import NavLink from 'src/components/NavLink';

import './TopSubmenu.css';

class TopSubmenu extends React.PureComponent {
  render() {
    const { pages } = this.props;

    return (
      <div className="TopSubmenu-outer">
        <div className="TopSubmenu-inner">
          <div className="TopSubmenu-linkList">
            {pages.map(page => {
              return (
                <div
                  key={page.url}
                  className="TopSubmenu-menuItem"
                >
                  <NavLink
                    to={page.url}
                    exact={page.exact}
                    className="TopSubmenu-link"
                    activeClassName="TopSubmenu-link--active"
                  >
                    {page.name}
                  </NavLink>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }
}

export default TopSubmenu;
