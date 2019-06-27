// @flow
import React from 'react';
import { Tag } from 'antd';
import { css } from 'emotion';

const styles = {
  wrapper: css`
    display: flex;
    flex-wrap: wrap;
    user-select: none;
  `,
  tag: css`
    &.ant-tag {
      margin-top: 4px;
      margin-bottom: 4px;
    }
  `
};

type Label = {
  name: string,
  value: string
};

export type ServerLabelsProps = {
  className?: string,
  labels?: Label[],
  onLabelClick?: (label: Label) => void
};

const ServerLabels = ({ className, labels, onLabelClick }: ServerLabelsProps) => (
  <div className={styles.wrapper}>
    {(labels || []).map(({ name, value}) => (
      <Tag
        color="darkgray"
        className={styles.tag}
        onClick={() => onLabelClick && onLabelClick({ name, value })}
      >
        {`${name}: ${value}`}
      </Tag>
    ))}
  </div>
);

export default ServerLabels;
