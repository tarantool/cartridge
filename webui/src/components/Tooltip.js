import * as React from 'react';
import { Popover } from 'antd';
import { css, cx } from 'emotion';

const styles = {
  wrapper: css`
    &:hover {
      cursor: pointer;
    }
  `,
  popover: css`
    & .ant-popover-inner-content {
      padding: 4px 16px;
      background: rgba(0, 0, 0, 0.85) !important;
      color: white;
      font-size: 12px;
      line-height: 20px;
      border-radius: 4px;
    }

    & .ant-popover-arrow {
      border-color: rgb(38, 38, 38) !important;
      border-width: 5.5px;
    }
  `
};

type TooltipProps = {
  children: React.Node,
  className?: string,
  placement?: string,
  content?: React.Node
};

function Tooltip({ children, className, placement = 'top', content }: TooltipProps) {
  return (
    <Popover overlayClassName={styles.popover} placement={placement} content={content} trigger='hover'>
      <div className={cx(styles.wrapper, className)}>
        {children}
      </div>
    </Popover>
  )
}

export default Tooltip;
