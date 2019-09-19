// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import Tooltip from 'src/components/Tooltip';
import { ControlsPanel, IconInfo, InputGroup, Text } from '@tarantool.io/ui-kit';

const styles = {
  wrap: css`
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
    margin-bottom: 16px;
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

type FormFieldProps = {
  children?: React.Node,
  className?: string,
  columns?: 1 | 2 | 3,
  info?: string | React.Node,
  itemClassName?: string,
  label?: string,
  subTitle?: string | React.Node,
  topRightControls?: React.Node[],
  verticalSort?: boolean
};

const FormField = ({
  children,
  topRightControls,
  itemClassName,
  className,
  subTitle,
  columns,
  info,
  label,
  verticalSort
}:
FormFieldProps) => (
  <div className={cx(styles.wrap, className)}>
    <div className={styles.headingPane}>
      {label && (
        <Text className={styles.label} variant='h4' tag='span'>{label}:
          {info && (
            <Tooltip className={styles.tooltip} content={info}>
              <IconInfo />
            </Tooltip>
          )}
        </Text>
      )}
      {subTitle && <Text className={styles.subTitle} variant='h5' tag='span' upperCase>{subTitle}</Text>}
      {topRightControls && <ControlsPanel className={styles.topRightControls} controls={topRightControls} />}
    </div>
    <InputGroup columns={columns} itemClassName={itemClassName} verticalSort={verticalSort}>{children}</InputGroup>
  </div>
);

export default FormField;
