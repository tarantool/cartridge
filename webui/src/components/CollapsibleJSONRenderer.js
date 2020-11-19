import React from 'react';
import { IconChevron, Text, baseFontFamily } from '@tarantool.io/ui-kit';
import { css, cx } from 'emotion';

const styles = {
  collapse: css`
    position: relative;
    margin-top: 6px;
    margin-bottom: 6px;

    input {
      display: none;
    }
  `,
  collapseIcon: css`
    margin-left: 8px;
    fill: #F5222D;
  `,
  structuredValue: css`
    overflow: hidden;
    display: inline-block;
    width: 100%;
    padding-right: 100px;
    line-height: 18px;
    white-space: nowrap;
    text-overflow: ellipsis;
  `,
  opened: css`
    padding-right: 0;
    white-space: pre;
    text-overflow: initial;
  `,
  collapseButton: css`
    position: absolute;
    right: 0;
    display: flex;
    align-items: center;
    padding: 0;
    border: 0;
    line-height: 18px;
    font-family: ${baseFontFamily};
    font-size: 14px;
    line-height: 22px;
    color: #f5222d;
    background-color: transparent;
    cursor: pointer;
    outline: none;

    &:focus::before {
      content: '';
      position: absolute;
      top: -2px;
      left: -2px;
      right: -2px;
      bottom: -2px;
      border: solid 1px rgba(245, 34, 45, 0.55);
      border-radius: 3px;
    }
  `
};

class CollapsibleJSONRenderer extends React.Component {
  state = {
    opened: false
  };

  render() {
    const { value } = this.props;
    const { opened } = this.state;

    return (
      <div className={styles.collapse}>
        <button className={styles.collapseButton} onClick={this.handleCollapseClick}>
          {'collapse '}
          <IconChevron className={styles.collapseIcon} direction={opened ? 'down' : 'up'} />
        </button>
        <Text
          variant="basic"
          className={cx(
            styles.structuredValue,
            { [styles.opened]: opened }
          )}
        >
          {JSON.stringify(value, null, 2)}
        </Text>
      </div>
    );
  };

  handleCollapseClick = () => this.setState(({ opened }) => ({ opened: !opened }));
};

export default CollapsibleJSONRenderer;

