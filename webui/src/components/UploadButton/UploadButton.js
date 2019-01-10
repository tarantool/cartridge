import P from 'prop-types';
import React from 'react';

import './UploadButton.css';

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
        <label className="UploadButton-label btn btn-primary"
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
