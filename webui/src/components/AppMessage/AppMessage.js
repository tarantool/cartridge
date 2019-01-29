import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import './AppMessage.css';

const prepareUndoneMessages = messages => {
  return messages.filter(message => ! message.done);
};

class AppMessage extends React.Component {
  constructor(props) {
    super(props);

    this.prepareUndoneMessages = defaultMemoize(prepareUndoneMessages);
  }

  render() {
    const messages = this.getUndoneMessages();

    return (
      <div className="AppMessage-outer">
        <div className="AppMessage-inner">
          {messages.map((message, index) => {
            const { content } = message;
            const className = `alert alert-${content.type} alert-dismissible fade show`;
            return (
              <div key={index} className={className}>
                <span>{content.text}</span>
                <button type="button" className="btn btn-link alert-link btn-lg"
                  onClick={() => this.handleDoneClick(content)}
                >
                  <span>&times;</span>
                </button>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  handleDoneClick = content => {
    const { setMessageDone } = this.props;
    setMessageDone({ content });
  };

  getUndoneMessages = () => {
    const { messages } = this.props;
    return this.prepareUndoneMessages(messages);
  };
}

AppMessage.propTypes = {
  messages: PropTypes.arrayOf(PropTypes.shape({
    content: PropTypes.shape({
      type: PropTypes.oneOf(['success', 'warning', 'danger']).isRequired,
      text: PropTypes.string.isRequired,
    }),
  })).isRequired,
  setMessageDone: PropTypes.func.isRequired,
};

export default AppMessage;
