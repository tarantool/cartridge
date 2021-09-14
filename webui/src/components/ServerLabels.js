// @flow
import React from 'react';
import { TagsList } from '@tarantool.io/ui-kit';

export type Label = {
  name: string,
  value: string,
};

export type ServerLabelsProps = {
  className?: string,
  labels?: Label[],
  onLabelClick?: (label: Label) => void,
  highlightingOnHover?: string,
};

const ServerLabels = ({ className, highlightingOnHover, labels, onLabelClick }: ServerLabelsProps) => {
  if (!labels || !labels.length) return null;

  return (
    <TagsList
      className={className}
      heading="Tags"
      highlightingOnHover={highlightingOnHover}
      values={labels}
      renderItem={({ name, value }) => `${name}: ${value}`}
      onTagClick={onLabelClick}
    />
  );
};

export default ServerLabels;
