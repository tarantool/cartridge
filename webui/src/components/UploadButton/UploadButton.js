import P from 'prop-types';
import React from 'react';

import './UploadButton.css';
import { css } from 'emotion';

const styles = {
  button: css`
    width: 170px;
    text-align: center;
    background-color: #FF272C;
    height: 40px;
    line-height: 40px;
    color: #FFF;
    border-radius: 6px;
    box-shadow: none;
    border: none;
    margin-top: 24px;
  `,
};

class UploadButton extends React.Component {
  constructor(props) {
    super(props);

    this.ref = null;
  }

  render() {
    const { label } = this.props;

    return (
      <div className="UploadButton-outer">
        <input ref={this.setRef} type="file" name="file" id="UploadButton-input" className="UploadButton-input"
          onChange={this.handleChange} />
        <label className={styles.button}
          htmlFor="UploadButton-input"
        >
          {label}
        </label>
      </div>
    )
  }

  setRef = ref => {
    this.ref = ref;
  }

  handleChange = event => {
    const { onChange } = this.props;
    onChange({
      files: this.ref.files,
      event,
    });
  }
}

UploadButton.propTypes = {
  label: P.string.isRequired,
  onChange: P.func.isRequired,
};

export default UploadButton;
