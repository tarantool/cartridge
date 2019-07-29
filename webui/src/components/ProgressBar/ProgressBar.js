import React from 'react';
import PropTypes from 'prop-types';
import { css, cx } from 'emotion';
import * as R from 'ramda';

const ACCENT_COLORS = {
  success: '96, 180, 66',
  warning: '207, 153, 52',
  danger: '255, 39, 44'
};

const BG_COLORS = {
  success: '203, 235, 197',
  warning: '243, 225, 194',
  danger: '255, 235, 237'
};

const defineStatus = R.cond([
  [R.lt(66), R.always('danger')],
  [R.lt(33), R.always('warning')],
  [R.T, R.always('success')]
]);

const style = css`
  display: inline-block;
  height: 6px;
  width: 100%;
  border-radius: 3px;
  background-repeat: no-repeat;
`;

const ProgressBar = ({ className, percents = 0, intention = defineStatus(percents) }) => {

  const colors = css`
    background-color: rgb(${ACCENT_COLORS[intention]});
    box-shadow: rgba(${BG_COLORS[intention]}, 0.5) 0px 1px 3px 1px;
    background-image: linear-gradient(
      to right,
      rgb(${ACCENT_COLORS[intention]}) ${percents}%,
      rgb(${BG_COLORS[intention]}) ${percents}%
    );
  `;

  return <span className={cx(className, style, colors)} />;
};

ProgressBar.propTypes = {
  className: PropTypes.string,
  percents: PropTypes.number,
  intention: PropTypes.oneOf(['danger', 'warning', 'success'])
};

export default ProgressBar;
