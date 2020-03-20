// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import { ControlsPanel, IconInfo, Text, Tooltip } from '@tarantool.io/ui-kit';

const styles = {
  wrap: css`
    display: block;
    margin-bottom: 24px;
  `,
  tooltip: css`
    display: inline-block;
    margin-left: 8px;
  `,
  headingPane: css`
    display: flex;
    flex-direction: row;
    align-items: baseline;
    margin-bottom: 8px;
  `,
  subTitle: css`
    margin-left: 32px;
  `,
  label: css`
    display: block;
  `,
  topRightControls: css`
    margin-left: auto;
  `
};

type LabeledInputProps = {
  children?: React.Node,
  className?: string,
  info?: string,
  itemClassName?: string,
  label: string,
  subTitle?: string | React.Node,
  topRightControls?: React.Node[]
};

const LabeledInput = ({
  children,
  topRightControls,
  itemClassName,
  className,
  subTitle,
  info,
  label
}:
LabeledInputProps) => (
  <label className={cx(styles.wrap, className)}>
    <div className={styles.headingPane}>
      <Text className={styles.label} variant='h4' tag='span'>{label}:
        {info && (
          <Tooltip className={styles.tooltip} content={info}>
            <IconInfo />
          </Tooltip>
        )}
      </Text>
      {subTitle && <Text className={styles.subTitle} variant='h5' tag='span' upperCase>{subTitle}</Text>}
      {topRightControls && <ControlsPanel className={styles.topRightControls} controls={topRightControls} />}
    </div>
    {children}
  </label>
);

export default LabeledInput;
