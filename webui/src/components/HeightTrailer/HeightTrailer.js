import PropTypes from 'prop-types';
import React from 'react';

import './HeightTrailer.css';

const SIZE_TRANSITION = 50;

class HeightTrailer extends React.PureComponent {
  constructor(props) {
    super(props);

    const { initialHeight } = props;

    this.trailer = null;
    this.topHandler = null;
    this.trailerHeight = initialHeight;
  }

  render() {
    const { children } = this.props;

    const trailerStyle = {
      height: `${this.trailerHeight}px`,
    };

    return (
      <div
        ref={this.setTrailer}
        className="HeightTrailer-trailer"
        style={trailerStyle}
      >
        <div
          ref={this.setTopHandler}
          className="HeightTrailer-topHandler"
          onMouseDown={this.handleMouseDown}
        />
        {children}
      </div>
    );
  }

  setTrailer = ref => {
    this.trailer = ref;
  };

  setTopHandler = ref => {
    this.topHandler = ref;
  };

  setSize = (size, transition = true) => {
    if (size.height != null) {
      this.trailerHeight = size.height;
      transition && (this.trailer.style.transition = `height ${SIZE_TRANSITION}ms`);
      this.trailer.style.height = `${size.height}px`;
      transition && setTimeout(() => this.trailer.style.transition = '', SIZE_TRANSITION);
    }
  };

  handleMouseDown = event => {
    event.preventDefault();
    const { minHeight, minTopDistance, onSizeChange } = this.props;

    this.topHandler.style.height = '1000px';
    this.topHandler.style.top = '-500px';

    const initialTrailerHeight = this.trailerHeight;
    let initialClientY = event.clientY;
    const onMouseMove = event => {
      const clientY = Math.max(minTopDistance, event.clientY);
      const delta = initialClientY - clientY;
      const nextHeight = Math.max(minHeight, initialTrailerHeight + delta);
      if (this.trailerHeight !== nextHeight) {
        const size = { height: nextHeight };
        this.setSize(size, false);
        onSizeChange && onSizeChange(size);
      }
    };
    const onMouseUp = () => {
      document.removeEventListener('mouseup', onMouseUp);
      document.removeEventListener('mousemove', onMouseMove);
      this.topHandler.style.height = '';
      this.topHandler.style.top = '';
    };

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
  };
}

HeightTrailer.propTypes = {
  minHeight: PropTypes.number,
  initialHeight: PropTypes.number.isRequired,
  minTopDistance: PropTypes.number,
  onSizeChange: PropTypes.func,
};

HeightTrailer.defaultProps = {
  minTopDistance: 0,
  minHeight: 0,
};

export default HeightTrailer;
