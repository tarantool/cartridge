import React from 'react';
import { css, cx } from 'react-emotion'
import Spin from 'src/components/Spin';

const styles = {
  panel: css`
    background: #FFF;
    border: 1px solid #F0F0F0;
    box-sizing: border-box;
    border-radius: 6px;
  `,
  cardHead: css`
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 1em 2em;
    font-size: 1.4em;
    border-bottom: 1px solid rgba(55, 52, 66, 0.08);
  `,
  container: css`
    padding-top: 24px;
  `,
  content: css`
    padding: 2em;
  `
};

const Card = ({
  className,
  children,
  loading = false,
  title = ''
}) => (
  <div className={cx(styles.container, className)}>
    <div className={styles.panel}>
      <Spin enable={loading}>
        <div className={styles.cardHead}>{title}</div>
        <div className={styles.content}>{children}</div>
      </Spin>
    </div>
  </div>
);

export default Card;
