import PropTypes from 'prop-types';
import React from 'react';
import ReactDOM from 'react-dom';
import ReactConsoleComponent from 'react-console-component';

import './Console.css';

class Console extends React.PureComponent {
  constructor(props) {
    super(props);

    this.console = null;
    this.consoleElement = null;
  }

  componentDidMount() {
    const { initialState } = this.props;

    if (initialState) {
      this.console.setState({ ...initialState });
    }
  }

  componentDidUpdate(prevProps) {
    const { result } = this.props;
    const { prevResult } = prevProps;

    if (result && result !== prevResult) {
      const message = `${result.output}\n`;
      this.console.logX(result.type, message);
      this.console.return();

      // react-console-component scroll fix
      setTimeout(() => (this.consoleElement.scrollTop = 100000000000), 100);
    }
  }

  render() {
    const { autofocus, welcomeMessage, getPromptLabel } = this.props;

    return (
      <div className="Console-console">
        <ReactConsoleComponent
          ref={this.setConsole}
          autofocus={autofocus}
          welcomeMessage={welcomeMessage}
          promptLabel={getPromptLabel}
          handler={this.handler} />
      </div>
    );
  }

  setConsole = ref => {
    this.console = ref;
    this.consoleElement = ReactDOM.findDOMNode(this.console);
  };

  handler = command => {
    const { handler } = this.props;
    handler({ command });
  };

  getConsoleState = () => {
    return this.console.state;
  };
}

Console.propTypes = {
  autofocus: PropTypes.bool,
  welcomeMessage: PropTypes.node.isRequired,
  getPromptLabel: PropTypes.func.isRequired,
  initialState: PropTypes.object,
  handler: PropTypes.func.isRequired,
  result: PropTypes.shape({
    output: PropTypes.string.isRequired,
    type: PropTypes.string.isRequired,
  }),
};

export default Console;
