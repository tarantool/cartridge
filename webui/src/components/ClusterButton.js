import React from 'react'
import {Button} from 'antd'
import {css} from 'react-emotion'

const buttonColor = '#343434';

const styles = {
  button: css`
    &.ant-btn:active{
      color: ${buttonColor};
      background-color: #fff;
      border-color: ${buttonColor};
    }
    &.ant-btn:hover, &.ant-btn:focus{
      color: ${buttonColor};
      background-color: #fff;
      border-color: ${buttonColor};
    }
    &.ant-btn-primary{
      color: #fff;
      background-color: ${buttonColor};
      border-color: ${buttonColor};
      text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.12);
      box-shadow: 0 2px 0 rgba(0, 0, 0, 0.045);
    }
    &.ant-btn-primary:hover, &.ant-btn-primary:focus {
      color: #fff;
      background-color: ${buttonColor};
      border-color: ${buttonColor};
      text-shadow: 0 -1px 0 rgba(0, 0, 0, 0.12);
      box-shadow: 0 2px 0 rgba(0, 0, 0, 0.045);
    }
  `
}

export default (props) => {
  return <Button {...props} className={styles.button}/>
}
