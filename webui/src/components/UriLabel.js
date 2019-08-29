// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import { IconLink } from 'src/components/Icon';
import Text from 'src/components/Text';

const styles = {
  uriWrap: css`
    display: flex;
    align-items: center;
  `,
  uriIcon: css`
    margin-right: 4px;
  `,
  uri: css`
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: rgba(0, 0, 0, 0.65);
  `
};

type UriLabelProps = {
  className?: string,
  uri?: string,
};

const UriLabel = ({ className, uri }: UriLabelProps) => (
  <div className={cx(styles.uriWrap, className)}>
    <IconLink className={styles.uriIcon} />
    <Text className={styles.uri} variant='h5' tag='span'>{uri}</Text>
  </div>
);

export default UriLabel;
