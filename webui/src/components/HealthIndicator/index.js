import React from 'react';
import PropTypes from 'prop-types';
import { css, cx } from 'emotion';

const styles = {
  indicator: css`
    display: inline-block;
    background-color: rgba(110, 97, 160, 0.04);
    border-radius: 50%;
  `,
  state: {
    bad: css`background-color: #FF272C;`,
    good: css`background-color: #60B442;`,
    middle: css`background-color: #d09935;`
  },
  size: {
    s: css`
      width: 8px;
      height: 8px;
    `,
    m: css`
    width: 13px;
    height: 13px;
  `,
    l: css`
    width: 16px;
    height: 16px;
  `
  }
};

const HealthIndicator = ({
  className,
  size = 's',
  state = 'inactive'
}) => {
  return (
    <span
      className={cx(
        className,
        styles.indicator,
        styles.state[state],
        styles.size[size]
      )}
    />
  );
};

HealthIndicator.propTypes = {
  className: PropTypes.string,
  size: PropTypes.oneOf(['s', 'm', 'l']),
  state: PropTypes.oneOf(['good', 'bad', 'middle'])
}

export default HealthIndicator;
