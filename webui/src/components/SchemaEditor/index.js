import * as monaco from 'monaco-editor/esm/vs/editor/edcore.main.js';
import { css, cx } from 'emotion';
import PropTypes from 'prop-types';
import React from 'react';
import { noop, throttle } from 'lodash';
import { subscribeOnTargetEvent } from '../../misc/eventHandler';
import { getYAMLError } from './yamlValidation';
import 'monaco-editor/esm/vs/basic-languages/yaml/yaml.contribution';

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
    monaco.languages.registerHoverProvider(SCHEMA_LANG, {
      provideHover: function (model, position) {
        if (!this.validationError) {
          return null;
        }

        const {
          endColumn,
          endLineNumber,
          message,
          startColumn,
          startLineNumber
        } = this.validationError;

        return {
          range: new monaco.Range(startLineNumber, startColumn, endLineNumber, endColumn),
          contents: [{ value: message }]
        }
      }
    });

    this.initMonaco();
    this.unsubcribeResize = subscribeOnTargetEvent(window, 'resize', this.throttledAdjustEditorSize)
  }

  adjustEditorSize = () => {
    if (this.containerElement && this.containerElement.current && this.editor) {
      const { width, height } = this.state;
      const { clientWidth, clientHeight } = this.containerElement.current;

      if (width !== clientWidth || height !== clientHeight) {
        this.setState(
          {
            height: clientHeight,
            width: clientWidth
          },
          () => this.editor.layout()
        );
      }
    }
  }

  throttledAdjustEditorSize = throttle(this.adjustEditorSize, 1000, { leading: false })

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
    this.throttledAdjustEditorSize()
    if (prevProps.options !== options) {
      editor.updateOptions(options);
    }
    if (prevProps.cursor !== cursor) {
      editor.setSelection(cursor)
      editor.revealLine(this.props.cursor.startLineNumber)
    }

    this.setValidationError();
  }

  componentWillUnmount() {
    this.destroyMonaco();
    this.unsubcribeResize();
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
    const yamlError = getYAMLError(this.editor.getValue());

    monaco.editor.setModelMarkers(
      model,
      'jsyaml',
      [
        ...(yamlError ? [getYAMLError(this.editor.getValue())] : [])
      ]
    );

    this.validationError = yamlError;
  }

  editorWillMount() {
    const { editorWillMount } = this.props;
    const options = editorWillMount(monaco);
    return options || {};
  }

  editorDidMount(editor) {
    this.props.editorDidMount(editor, monaco);

    this.adjustEditorSize();

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