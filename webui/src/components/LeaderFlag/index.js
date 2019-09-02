// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import greenFlag from './flag.svg';
import redFlag from './flag-red.svg';

const styles = {
  wrap: css`
    position: relative;
    width: 14px;
    height: 17px;
    overflow: hidden;
    transition: height 0.3s ease-in-out;

    &:hover {
      height: 59px;
    }
  `,
  flag: css`
    position: absolute;
    left: 0;
    bottom: 0;
    width: 14px;
    height: 59px;
  `
};

type LeaderFlagProps = {
  className?: string,
  fail?: boolean
};

const LeaderFlag = ({ className, fail }: LeaderFlagProps) => {
  const glyph = fail ? redFlag : greenFlag;
  return (
    <div className={cx(styles.wrap, className)}>
      <svg
        viewBox={glyph.viewBox}
        className={styles.flag}
      >
        <use xlinkHref={`#${glyph.id}`}/>
      </svg>
    </div>
  )
};

export default LeaderFlag;
