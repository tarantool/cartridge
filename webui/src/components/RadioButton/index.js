import * as React from 'react'
import {css} from 'react-emotion'
import PropTypes from 'prop-types'
import cn from 'src/misc/cn'

const styles = {
  main: css`
    
  `,
  container: css`
    display: inline-block;
    vertical-align: middle;
  `,
  radio: css`
    display: none;
  `,
  label: css`
  `,
  visible: css`
    border-radius: 100%;
    background: #FFFFFF;
    border: 1px solid #DCDCDC;
    box-sizing: border-box;
    position: relative;
    cursor: pointer;
    display: inline-block;
    vertical-align: middle;
  `,
  checked: css`
    background: #838383;
    &:after{
      top: 50%;
      left: 50%;
      position: absolute;
      transform: translateX(-50%) translateY(-50%);
      width: 9px;
      height: 9px;
      content: '';
      display: block;
      z-index: 2;
      background: #fff;
      border-radius: 100%;
    }
  `,
  disabled: css`
    cursor: cursor;
    background: #838383;
  `,
}

export default class RadioButton extends React.Component{
  static propTypes = {
    name: PropTypes.string,
    checked: PropTypes.bool.isRequired,
    disabled: PropTypes.bool,
    onChange: PropTypes.func,
    id: PropTypes.string,
    size: PropTypes.number,
    className: PropTypes.string,
    value: PropTypes.string,
  }
  static defaultProps = {
    name: '',
    disabled: false,
    size: 20,
    className: '',
    value: '',
  }
  render() {
    const {name, checked, disabled, onChange, id, className, size, value} = this.props
    const sizeStyle = {width: `${size}px`, height: `${size}px`};
    const viewClassName = styles.visible + ' ' +
      cn(checked && styles.checked, disabled && styles.disabled)
    return <label className={`${styles.container} ${className}`}>
          <input
            id={id}
            className={styles.radio}
            type={'radio'}
            name={name}
            checked={checked}
            disabled={disabled}
            onChange={onChange}
            value={value}
          />
          <div className={viewClassName} style={sizeStyle}></div>
        </label>
  }
};
