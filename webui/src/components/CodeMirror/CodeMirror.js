import React from 'react';
import { UnControlled as CodemirrorUnControlled } from 'react-codemirror2';
import PropTypes from 'prop-types';

import 'codemirror/lib/codemirror.css';
import 'codemirror/theme/neo.css';
import 'codemirror/mode/xml/xml';
import 'codemirror/mode/javascript/javascript';
import 'codemirror/mode/yaml/yaml';
import 'codemirror/mode/yaml-frontmatter/yaml-frontmatter';
import './CodeMirror.css';

class CodeMirror extends React.Component {
  render() {
    const { value, mode, readOnly, onChange } = this.props;

    return (
      <CodemirrorUnControlled
        value={value}
        options={{
          mode,
          theme: 'neo',
          readOnly,
        }}
        onChange={onChange}
      />
    );
  }
}

CodeMirror.propTypes = {
  value: PropTypes.string,
  mode: PropTypes.string,
  readOnly: PropTypes.bool,
  onChange: PropTypes.func,
};

CodeMirror.defaultProps = {
  value: '',
  mode: 'xml',
  readOnly: false,
};

export default CodeMirror;
