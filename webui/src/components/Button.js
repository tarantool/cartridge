import React from 'react'
import Button from 'antd/lib/button'
import { css } from 'react-emotion'

const activeColor = '#343434';
const baseColor = '#464646';
const hoverColor = '#666666';

const styles = {
  button: css`
    &.ant-btn:active {
      color: ${baseColor};
      background-color: #fff;
      border-color: ${baseColor};
    }
    &.ant-btn:hover, &.ant-btn:focus {
      color: ${baseColor};
      background-color: #fff;
      border-color: ${hoverColor};
    }
    &.ant-btn:active {
      color: ${activeColor};
      border-color: ${activeColor};
    }
    &.ant-btn-primary {
      color: #fff;
      background-color: ${baseColor};
      border-color: ${baseColor};
      text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.12);
      box-shadow: 0 2px 0 rgba(0, 0, 0, 0.045);
    }
    &.ant-btn-primary:hover, &.ant-btn-primary:focus {
      color: #fff;
      background-color: ${hoverColor};
      border-color: ${hoverColor};
      text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.12);
      box-shadow: 0 2px 0 rgba(0, 0, 0, 0.045);
    },
    &.ant-btn-primary:active {
      background-color: ${activeColor};
      border-color: ${activeColor};
    }
  `
}

export default props => {
  return <Button {...props} className={styles.button}/>
}
