import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';
import PropTypes from 'prop-types';
import React from 'react';
import { noop, throttle } from 'lodash';
import { subscribeOnTargetEvent } from '../../misc/eventHandler';

const DEF_CURSOR = {}

export default class MonacoEditor extends React.Component {
  static propTypes = {
    value: PropTypes.string,
    defaultValue: PropTypes.string,
    language: PropTypes.string,
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
    language: 'javascript',
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

  containerElement = null;
  editor = null;
  _subscription = null;

  componentDidMount() {
    this.initMonaco();
    this.unsubcribeResize = subscribeOnTargetEvent(window, 'resize', this.throttledAdjustEditorSize)
  }

  adjustEditorSize() {
    if (this.containerElement && this.editor) {
      const { width, height } = this.state
      const { clientWidth, clientHeight } = this.containerElement
      if (width !== clientWidth && height !== clientHeight) {
        this.setState(() => ({
          height: clientHeight,
          width: clientWidth
        }), () => {
          this.editor.layout()
        })
      }
    }
  }

  throttledAdjustEditorSize = throttle(this.adjustEditorSize, 1000, { leading: false })

  componentDidUpdate(prevProps) {
    const {
      value, language, theme, cursor, options
    } = this.props;

    const { editor } = this;
    const model = editor.getModel();

    if (this.props.value !== model.getValue()) {
      this.__prevent_trigger_change_event = true;
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
      this.__prevent_trigger_change_event = false;
    }
    if (prevProps.language !== language) {
      monaco.editor.setModelLanguage(model, language);
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
  }

  componentWillUnmount() {
    this.destroyMonaco();
    this.unsubcribeResize();
  }

  assignRef = component => {
    this.containerElement = component;
  };

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
    const { language, theme, options, overrideServices } = this.props;
    if (this.containerElement) {
      // Before initializing monaco editor
      Object.assign(options, this.editorWillMount());
      this.editor = monaco.editor.create(
        this.containerElement,
        {
          value,
          language,
          ...options,
          ...(theme ? { theme } : {})
        },
        overrideServices
      );
      // After initializing monaco editor
      this.editorDidMount(this.editor);
    }
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
      if (!this.__prevent_trigger_change_event) {
        this.props.onChange(editor.getValue());
      }
    });
  }

  render() {
    const { styles: styleObj, className } = this.props;

    return (
      <div
        ref={this.assignRef}
        style={styleObj}
        className={className}
      />
    );
  }
}
