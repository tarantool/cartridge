import React from 'react';

import cn from 'src/misc/cn';

import './SVGIcon.css';

export default function SVGIcon(props) {
  const { className } = props;

  return (
    // eslint-disable-next-line jsx-a11y/alt-text
    <img
      {...props}
      className={cn(className, 'SVGIcon')}
    />
  );
}

export function createSVGIcon(defaultProps) {
  function Icon(props) {
    const { className } = props;
    return (
      <SVGIcon
        {...defaultProps}
        {...props}
        className={cn(className, defaultProps.className)}
      />
    );
  }
  Icon.displayName = `SVGIcon-${defaultProps.displayName || defaultProps.alt}`;
  return Icon;
}
