// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';

const styles = {
  tab: css`
    position: relative;
    padding: 16px;
    border: none;
    border-bottom: solid 2px transparent;
    font-size: 16px;
    line-height: 16px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.65);
    outline: none;

    &:focus {
      z-index: 1;
    }

    &:focus::before {
      /* TODO: focus state */
    }
  `,
  activeTab: css`
    color: #CF1322;
    border-bottom-color: #CF1322;
  `

};

type Tab = {
  label: string,
  content: React.Node
};

type TabbedProps = {
  tabs?: Tab[],
  className?: string,
};

class Tabbed extends React.Component<TabbedProps> {
  state = {
    activeTab: 0
  };

  render() {
    const { className, tabs = [] } = this.props;
    const { activeTab } = this.state;

    return (
      <div className={className}>
        <div className={styles.tabs}>
          {tabs && tabs.map(({ label }, i) => (
            <button
              className={cx(
                styles.tab,
                { [styles.activeTab]: activeTab === i }
              )}
              onClick={() => this.handleTabChange(i)}
            >
              {label}
            </button>
          ))}
        </div>
        {tabs[activeTab].content}
      </div>
    );
  }

  handleTabChange(i) {
    this.setState({ activeTab: i })
  }
}

export default Tabbed;
