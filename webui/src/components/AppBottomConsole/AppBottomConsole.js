import PropTypes from 'prop-types';
import React from 'react';
import ReactDOM from 'react-dom';

import HeightTrailer from 'src/components/HeightTrailer';

import './AppBottomConsole.css';

const INITIAL_COSOLE_HEIGHT = 400;
const MIN_CONSOLE_HEIGHT = 54;
const MIN_CONSOLE_TOP_DISTANCE = 86; /* magic: TOP_MENU_HEIGHT + PAGE_BOTTON_MARGIN */

class AppBottomConsole extends React.PureComponent {
  constructor(props) {
    super(props);

    this.trailer = null;
    this.trailerElement = null;
  }

  componentDidMount() {
    const { onSizeChange } = this.props;
    onSizeChange({ height: INITIAL_COSOLE_HEIGHT });
  }

  render() {
    const { children, title, onSizeChange, onClose } = this.props;

    return (
      <div className="AppBottomConsole-window app-bottomConsole">
        <HeightTrailer
          ref={this.setTrailer}
          initialHeight={INITIAL_COSOLE_HEIGHT}
          minHeight={MIN_CONSOLE_HEIGHT}
          minTopDistance={MIN_CONSOLE_TOP_DISTANCE}
          onSizeChange={onSizeChange}
        >
          <div className="AppBottomConsole-windowContent">
            <div className="AppBottomConsole-head">
              <div className="AppBottomConsole-header">
                {title}
              </div>
              <div className="AppBottomConsole-windowButtons">
                <span
                  className="AppBottomConsole-windowButton"
                  onClick={onClose}
                >
                  x
                </span>
                <span
                  className="AppBottomConsole-windowButton"
                  onClick={this.handleWrap}
                >
                  –
                </span>
                <span
                  className="AppBottomConsole-windowButton"
                  onClick={this.handleUnwrap}
                >
                  □
                </span>
              </div>
            </div>
            <div className="AppBottomConsole-console">
              {children}
            </div>
          </div>
        </HeightTrailer>
      </div>
    );
  }

  setTrailer = ref => {
    this.trailer = ref;
    this.trailerElement = ReactDOM.findDOMNode(this.trailer);
  };

  handleWrap = () => {
    const { onSizeChange } = this.props;
    const size = { height: MIN_CONSOLE_HEIGHT };
    this.trailer.setSize(size);
    onSizeChange(size);
  };

  handleUnwrap = () => {
    const { onSizeChange } = this.props;
    const rect = this.trailerElement.getBoundingClientRect();
    const size = { height: rect.height + rect.top - MIN_CONSOLE_TOP_DISTANCE };
    this.trailer.setSize(size);
    onSizeChange(size);
  };
}

export default AppBottomConsole;

AppBottomConsole.propTypes = {
  title: PropTypes.string.isRequired,
  onSizeChange: PropTypes.func,
  onClose: PropTypes.func.isRequired,
};
