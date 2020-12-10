import { css, cx } from 'emotion';
import PropTypes from 'prop-types';
import React from 'react';
import { noop, throttle } from 'lodash';
import monaco from '../../misc/initMonacoEditor';
import { getYAMLError } from '../../misc/yamlValidation';

const containerStyles = css`
  overflow: hidden;
`;

const DEF_CURSOR = {};
const SCHEMA_LANG = 'yaml';

export default class SchemaEditor extends React.Component {
  static propTypes = {
    value: PropTypes.string,
    fileId: PropTypes.string,
    defaultValue: PropTypes.string,
    theme: PropTypes.string,
    options: PropTypes.object,
    overrideServices: PropTypes.object,
    editorDidMount: PropTypes.func,
    editorWillMount: PropTypes.func,
    onChange: PropTypes.func,
    styles: PropTypes.object,
    className: PropTypes.string,
    cursor: PropTypes.object
  };

  static defaultProps = {
    value: null,
    defaultValue: '',
    theme: null,
    options: {},
    overrideServices: {},
    editorDidMount: noop,
    editorWillMount: noop,
    onChange: noop,
    styles: {},
    className: '',
    cursor: DEF_CURSOR
  };

  state = {
    width: 0,
    height: 0
  }

  containerElement = React.createRef();
  editor = null;
  _subscription = null;
  _prevent_trigger_change_event = false;

  componentDidMount() {
    this.initMonaco();
  }

  componentDidUpdate(prevProps) {
    const {
      value,
      fileId,
      theme,
      cursor,
      options
    } = this.props;

    const { editor } = this;
    let model = editor.getModel(fileId)

    if (this.props.value !== model.getValue()) {
      this._prevent_trigger_change_event = true;
      this.editor.pushUndoStop();
      model.pushEditOperations(
        [],
        [
          {
            range: model.getFullModelRange(),
            text: value
          }
        ]
      );
      this.editor.pushUndoStop();
      this._prevent_trigger_change_event = false;
    }


    if (prevProps.theme !== theme) {
      monaco.editor.setTheme(theme);
    }
    if (prevProps.options !== options) {
      editor.updateOptions(options);
    }
    if (prevProps.cursor !== cursor) {
      editor.setSelection(cursor)
      editor.revealLine(this.props.cursor.startLineNumber)
    }

    this.throttledSetValidationError();
  }

  componentWillUnmount() {
    this.destroyMonaco();
  }

  destroyMonaco() {
    if (this.editor) {
      this.editor.dispose();
    }
    if (this._subscription) {
      this._subscription.dispose();
    }
  }

  initMonaco() {
    const value =
      this.props.value !== null ? this.props.value : this.props.defaultValue;
    const { theme, options, overrideServices } = this.props;
    if (this.containerElement && this.containerElement.current) {
      // Before initializing monaco editor
      Object.assign(options, this.editorWillMount());

      this.editor = monaco.editor.create(
        this.containerElement.current,
        {
          value,
          language: SCHEMA_LANG,
          fixedOverflowWidgets: true,
          automaticLayout: true,
          ...options,
          ...(theme ? { theme } : {})
        },
        overrideServices
      );
      this.editorDidMount(this.editor);
    }
  }

  setValidationError = () => {
    const { editor } = this;
    let model = editor.getModel(this.props.fileId);
    const yamlError = getYAMLError(editor.getValue());

    monaco.editor.setModelMarkers(
      model,
      'jsyaml',
      [
        ...(yamlError ? [getYAMLError(editor.getValue())] : [])
      ]
    );

    this.validationError = yamlError;
  }

  throttledSetValidationError = throttle(this.setValidationError, 1000, { leading: false })

  editorWillMount() {
    const { editorWillMount } = this.props;
    const options = editorWillMount(monaco);
    return options || {};
  }

  editorDidMount(editor) {
    this.props.editorDidMount(editor, monaco);

    if (this.props.cursor !== DEF_CURSOR) {
      editor.setSelection(this.props.cursor)
      editor.revealLine(this.props.cursor.startLineNumber)
    }

    this._subscription = editor.onDidChangeModelContent(() => {
      if (!this._prevent_trigger_change_event) {
        this.props.onChange(editor.getValue());
      }
    });
  }

  render() {
    const { styles: styleObj, className } = this.props;

    return (
      <div
        ref={this.containerElement}
        style={styleObj}
        className={cx(containerStyles, className)}
      />
    );
  }
}
