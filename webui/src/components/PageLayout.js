// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';

const styles = {
  page: css`
    display: flex;
    flex-direction: column;
    min-height: 100%;
    background: #f0f2f5; /* this color should be set in core */
    padding: 24px 32px;
  `
};

type PageLayoutProps = {
  children: React.Node,
  className: string
};

const PageLayout = ({ children, className }: PageLayoutProps) => (
  <div className={cx(styles.page, className)}>{children}</div>
);

export default PageLayout;
