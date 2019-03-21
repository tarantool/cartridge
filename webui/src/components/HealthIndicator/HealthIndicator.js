import React from 'react';
import PropTypes from 'prop-types';
import cn from 'classnames';
import './HealthIndicator.scss';

const CLASS_NAME = 'HealthIndicator';

const HealthIndicator = ({
  className,
  size = 's',
  state = "inactive"
}) => {
  return (
    <span
      className={cn(
        className,
        CLASS_NAME,
        `${CLASS_NAME}--state-${state}`,
        `${CLASS_NAME}--size-${size}`
      )}
    />
  );
};

HealthIndicator.propTypes = {
  className: PropTypes.string,
  size: PropTypes.oneOf(['s', 'm', 'l']),
  state: PropTypes.oneOf(['good', 'bad', 'middle'])
}

export default HealthIndicator;
