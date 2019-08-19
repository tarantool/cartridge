// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'react-emotion'
import Spin from 'src/components/Spin';
import Text from 'src/components/Text';
import { IconClose } from 'src/components/Icon';

const styles = {
  container: css`
    padding: 16px;
    border: 1px solid #e8e8e8;
    border-radius: 4px;
    margin: 0 -16px 48px;
    background: #ffffff;
    box-shadow: 0px 1px 10px rgba(0, 0, 0, 0.06);
  `,
  cardHead: css`
    padding-bottom: 16px;
    border-bottom: 1px solid rgba(55, 52, 66, 0.08);
    margin-bottom: 16px;
  `,
  closeIcon: css`
    position: absolute;
    top: 0;
    right: 0;
  `
};

const PageCard = ({
  className,
  children,
  showCorner,
  onClose,
  loading = false,
  title = ''
}) => (
  <div
    className={cx(
      styles.container,
      { [styles.corner]: showCorner },
      className
    )}
  >
    <Spin enable={loading}>
      <Text className={styles.cardHead} variant='h2'>{title}</Text>
      {onClose && <IconClose className={styles.closeIcon} onClick={onClose} />}
      <div>{children}</div>
    </Spin>
  </div>
);

export default PageCard;
