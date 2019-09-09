import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import { css } from 'emotion'
import { Icon } from 'antd';

const styles = {
  closeBtn: css`
    border: none;
    background: transparent;
    cursor: pointer;
  `,
  outer: css`
    position: fixed;
    bottom: 0;
    left: 0;
    width: 100%;
    padding-left: 243px;
  `,
  inner: css`
    padding-right: 60px;
    padding-left: 60px;
  `
};

const ICON_TYPES = {
  success: 'check-circle',
  error: 'close-circle',
  warning: 'exclamation-circle'
};

const prepareUndoneMessages = messages => {
  return messages.filter(message => !message.done);
};

class AppMessage extends React.Component {
  constructor(props) {
    super(props);

    this.prepareUndoneMessages = defaultMemoize(prepareUndoneMessages);
  }

  render() {
    const messages = this.getUndoneMessages();

    return (
      <div className={styles.outer}>
        <div className={styles.inner}>
          {messages.map(({ content }, index) => (
            <div className="ant-notification-notice ant-notification-notice-closable" key={index}>
              <div className="ant-notification-notice-content">
                <div className="ant-notification-notice-with-icon">
                  <Icon
                    className={`ant-notification-notice-icon ant-notification-notice-icon-${content.type}`}
                    type={ICON_TYPES[content.type]}
                  />
                  <div className="ant-notification-notice-description">{content.text}</div>
                </div>
              </div>
              <button
                type="button"
                className={`ant-notification-notice-close ${styles.closeBtn}`}
                onClick={() => this.handleDoneClick(content)}
              >
                <Icon className="ant-notification-close-icon" type="close" />
              </button>
            </div>
          ))}
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
      type: PropTypes.oneOf(['success', 'warning', 'error']).isRequired,
      text: PropTypes.string.isRequired
    })
  })).isRequired,
  setMessageDone: PropTypes.func.isRequired
};

export default AppMessage;
