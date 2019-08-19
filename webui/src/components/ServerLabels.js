// @flow
// TODO: move to uikit
import React from 'react';
import TagsList from 'src/components/TagsList';

export type Label = {
  name: string,
  value: string
};

export type ServerLabelsProps = {
  className?: string,
  labels?: Label[],
  onLabelClick?: (label: Label) => void,
  highlightingOnHover?: string
};

const ServerLabels = ({ className, highlightingOnHover, labels, onLabelClick }: ServerLabelsProps) => (
  <TagsList
    className={className}
    heading='Tags'
    highlightingOnHover={highlightingOnHover}
    values={labels}
    renderItem={({ name, value }) => `${name}: ${value}`}
    onTagClick={onLabelClick}
  />
);

export default ServerLabels;
