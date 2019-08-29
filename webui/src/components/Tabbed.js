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
    font-family: 'Open Sans', sans-serif;
    font-size: 16px;
    line-height: 16px;
    font-weight: 600;
    color: rgba(0, 0, 0, 0.65);
    background-color: transparent;
    outline: none;
    cursor: pointer;

    &:focus {
      z-index: 1;
    }

    &:focus::before {
      content: '';
      position: absolute;
      top: -1px;
      left: -2px;
      right: -2px;
      bottom: -4px;
      border: solid 1px rgba(245, 34, 45, 0.55);
      border-radius: 3px;
    }
  `,
  activeTab: css`
    color: #CF1322;
    border-bottom-color: #CF1322;
  `,
  tabs: css``
};

type Tab = {
  label: string,
  content: React.Node
};

type TabbedProps = {
  tabs?: Tab[],
  className?: string,
};

type TabbedState = {
  activeTab: number,
}

class Tabbed extends React.Component<TabbedProps, TabbedState> {
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

  handleTabChange(i: number) {
    this.setState({ activeTab: i })
  }
}

export default Tabbed;
