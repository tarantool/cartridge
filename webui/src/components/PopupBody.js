// @flex
import * as React from 'react';
import { css, cx } from 'emotion';
import Scrollbar from 'src/components/Scrollbar';

const styles = {
  wrap: css`
    width: 100%;
    height: 100%;
  `,
  scrollableWrap: css`
    height: 100%;
    margin-left: -16px;
    margin-right: -16px;
  `,
  scrollableBody: css`
    padding-left: 16px;
    padding-right: 16px;
  `
};

type PopupBodyProps = {
  children?: React.Node,
  className?: string,
  innerClassName?: string,
  scrollable?: boolean
};

const PopupBody = ({ children, className, innerClassName, scrollable }: PopupBodyProps) => scrollable
  ? (
    <Scrollbar className={cx(styles.scrollableWrap, className)}>
      <div className={cx(styles.scrollableBody, innerClassName)}>
        {children}
      </div>
    </Scrollbar>
  )
  : (
    <div className={cx(styles.wrap, className)}>
      {children}
    </div>
  );

export default PopupBody;
