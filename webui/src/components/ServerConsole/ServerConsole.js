import PropTypes from 'prop-types';
import React from 'react';

import { getServerConsoleFullUrl, getServerName } from 'src/app/misc';
import Console from 'src/components/Console';
import Link from 'src/components/Link';
import cn from 'src/misc/cn';

import './ServerConsole.css';

class ServerConsole extends React.PureComponent {
  constructor(props) {
    super(props);

    this.console = null;
    this.welcomeMessage = this.getWelcomeMessage();
  }

  render() {
    const { autofocus, initialState, server, handler, result } = this.props;

    return (
      <div className="ServerConsole-console">
        <Console
          key={server.uuid}
          ref={this.setConsole}
          autofocus={autofocus}
          welcomeMessage={this.welcomeMessage}
          getPromptLabel={this.getPromptLabel}
          initialState={initialState}
          handler={handler}
          result={result} />
      </div>
    );
  }

  setConsole = ref => {
    this.console = ref;
  };

  getConsoleState = () => {
    return this.console.getConsoleState();
  };

  getWelcomeMessage = () => {
    const { shouldDisplayServerListMessage } = this.props;

    return (
      <div className="ServerConsole-welcomeBlock">
        {shouldDisplayServerListMessage
          ? this.getServerListMessage()
          : null}
        <div className="ServerConsole-welcomeMessage">
          *** Welcome to tarantool web console ***
        </div>
        <span className="ServerConsole-blankLine">
          {' '}
        </span>
      </div>
    );
  };

  getServerListMessage = () => {
    const { clusterSelf, server, serverList } = this.props;
    const serverUri = server.uri;

    return (
      <div className="ServerConsole-serverListBlock">
        <div className="ServerConsole-serverListMessage">
          {serverList
            .filter(server => server.uuid)
            .map(server => {
              const serverName = getServerName(server, clusterSelf);
              const serverLink = getServerConsoleFullUrl(server, clusterSelf);
              const linkClassName = cn(
                'ServerConsole-serverConsoleLink',
                server.uri === serverUri && 'ServerConsole-serverConsoleLink--active',
              );

              return (
                <React.Fragment>
                  {'['}
                  <Link
                    to={serverLink}
                    className={linkClassName}
                  >
                    {serverName}
                  </Link>
                  {']'}
                  <span>{' '}</span>
                </React.Fragment>
              );
            })
          }
        </div>
        <span className="ServerConsole-blankLine">
          {' '}
        </span>
      </div>
    );
  };

  getPromptLabel = () => {
    const { clusterSelf, server } = this.props;
    return `${getServerName(server, clusterSelf)}: `;
  };
}

ServerConsole.propTypes = {
  autofocus: PropTypes.bool,
  initialState: PropTypes.any,
  clusterSelf: PropTypes.shape({
    uri: PropTypes.string.isRequired,
  }),
  server: PropTypes.shape({
    uri: PropTypes.string.isRequired,
    alias: PropTypes.string,
  }).isRequired,
  shouldDisplayServerListMessage: PropTypes.bool,
  serverList: PropTypes.arrayOf(PropTypes.shape({
    uri: PropTypes.string.isRequired,
    alias: PropTypes.string,
  })),
  handler: PropTypes.func.isRequired,
  result: PropTypes.any,
};

ServerConsole.defaultProps = {
  shouldDisplayServerListMessage: false,
};

export default ServerConsole;
