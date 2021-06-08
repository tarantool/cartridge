import React from 'react';
import {
  Button,
  CodeBlock,
  IconChevron
} from '@tarantool.io/ui-kit';
import { css } from '@emotion/css';

const styles = {
  collapse: css`
    position: relative;
    align-self: stretch;
    max-width: 50%;
    margin-top: 6px;
    margin-bottom: 6px;

    input {
      display: none;
    }
  `,
  opened: css`
    padding-right: 0;
    white-space: pre;
    text-overflow: initial;
  `,
  collapseButton: css`
    position: absolute;
    top: 0;
    right: 0;
  `,
  contentWrap: css`
    width: 100%;
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
      <>
        <div className={styles.collapse}>
          <Button
            className={styles.collapseButton}
            onClick={this.handleCollapseClick}
            size='m'
            intent='plain'
            title='Expand'
            icon={({ className }) => (
              <IconChevron
                className={className}
                direction={opened ? 'up' : 'down'}
              />
            )}
          />
        </div>
        {opened && (
          <div className={styles.contentWrap}>
            {!!value && (
              <CodeBlock
                text={JSON.stringify(value, null, 2)}
              />
            )}
          </div>
        )}
      </>
    );
  };

  handleCollapseClick = () => this.setState(({ opened }) => ({ opened: !opened }));
};

export default CollapsibleJSONRenderer;

