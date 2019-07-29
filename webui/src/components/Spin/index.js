import React from 'react';
import PropTypes from 'prop-types';
import { css, cx } from 'emotion';

const styles = {
  wrap: css`
    position: relative;
  `,

  spin: css`
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate3d(-50%, -50%, 0);
  `,

  animated: css`
    margin: 100px auto;
    width: 60px;
    height: 60px;
    text-align: center;
    font-size: 10px;
  `,

  rect: css`
    background-color: #333;
    height: 100%;
    width: 7px;
    margin: 0 3px 0 0;
    display: inline-block;
    -webkit-animation: cluster-spin-sk-stretchdelay 1.2s infinite ease-in-out;
    animation: cluster-spin-sk-stretchdelay 1.2s infinite ease-in-out;

    &.rect2 {
      -webkit-animation-delay: -1.1s;
      animation-delay: -1.1s;
    }

    &.rect3 {
      -webkit-animation-delay: -1.0s;
      animation-delay: -1.0s;
    }

    &.rect4 {
      -webkit-animation-delay: -0.9s;
      animation-delay: -0.9s;
    }

    &.rect5 {
      -webkit-animation-delay: -0.8s;
      animation-delay: -0.8s;
    }

    @-webkit-keyframes cluster-spin-sk-stretchdelay {
      0%, 40%, 100% { -webkit-transform: scaleY(0.4) }
      20% { -webkit-transform: scaleY(1.0) }
    }

    @keyframes cluster-spin-sk-stretchdelay {
      0%, 40%, 100% {
        transform: scale3d(1, 0.4, 1);
        -webkit-transform: scale3d(1, 0.4, 1);
      }
      20% {
        transform: scale3d(1, 1.0, 1);
        -webkit-transform: scale3d(1, 1.0, 1);
      }
    }
  `,

  container: css`
    &.blur {
      pointer-events: none;
      -webkit-user-select: none;
      -moz-user-select: none;
      -ms-user-select: none;
      user-select: none;
      overflow: hidden;
      opacity: .5;
    }
  `
};

export default class Spin extends React.Component {
  static propTypes = {
    enable: PropTypes.bool
  };

  static defaultProps = {
    enable: false
  };

  render() {
    const { children, enable } = this.props;
    return (
      <div className={styles.wrap}>
        {enable && this.renderSpin()}
        <div className={cx(styles.container, { 'blur': enable })}>{children}</div>
      </div>
    );
  }

  renderSpin(){
    return <div className={styles.spin}>
      <div className={styles.animated}>
        <div className={styles.rect}></div>
        <div className={cx(styles.rect, 'rect2')}></div>
        <div className={cx(styles.rect, 'rect3')}></div>
        <div className={cx(styles.rect, 'rect4')}></div>
        <div className={cx(styles.rect, 'rect5')}></div>
      </div>
    </div>;
  }
}
