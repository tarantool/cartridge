import CheckboxDisabled from './chekbox_disabled.svg'
import CheckboxChecked from './chekbox_checked.svg'
import CheckboxUnchecked from './chekbox_unchecked.svg'
import PropTypes from 'prop-types'
import * as React from 'react'
import {css} from 'react-emotion'

const styles = {
  visibleBox: css`
    display: inline-block;
  `,
  enabled: css`
    cursor: pointer;
  `,
  container: css`
    display: inline-block;
  `,
  label: css`
    display: inline-block;
  `,
}

styles.checkbox = css`
  display: none;
`

export default class Checkbox extends React.Component{
  static propTypes = {
    name: PropTypes.string,
    checked: PropTypes.bool.isRequired,
    onChange: PropTypes.func,
    disabled:PropTypes.bool,
    size: PropTypes.number,
    className: PropTypes.string,
    id: PropTypes.string,
  };
  static defaultProps = {
    size: 20,
    className: '',
    id: '',
  };
  render(){
    const {name, checked, disabled, size, className, id} = this.props;
    const pickImage = disabled ? CheckboxDisabled : (checked ? CheckboxChecked : CheckboxUnchecked);
    const styleObj = {
      height: `${size}px`,
      width: `${size}px`,
    }
    return <div className={`${styles.container} ${className}`}>
      <label className={styles.label}>
        <input
          type="checkbox"
          checked={checked}
          name={name || ''}
          id={id}
          className={styles.checkbox}
          onChange={this.props.onChange}
        />
        <img
          style={styleObj}
          alt={''}
          className={`${styles.visibleBox} ${disabled ? '' : styles.enabled}`}
          src={pickImage}
        />
       </label>
    </div>
  }
}
