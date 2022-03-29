import React from 'react';
import { noop, throttle } from 'lodash';

import monaco from '../../misc/initMonacoEditor';
import { getModelByFile, setModelByFile } from '../../misc/monacoModelStorage';
import { getYAMLError } from '../../misc/yamlValidation';

const DEF_CURSOR = {};

export default class MonacoEditor extends React.Component {
  // static propTypes = {
  //   fileId: PropTypes.string,
  //   initialValue: PropTypes.string,
  //   language: PropTypes.string,
  //   theme: PropTypes.string,
  //   options: PropTypes.object,
  //   overrideServices: PropTypes.object,
  //   editorDidMount: PropTypes.func,
  //   editorWillMount: PropTypes.func,
  //   onChange: PropTypes.func,
  //   isContentChanged: PropTypes.bool,
  //   setIsContentChanged: PropTypes.func,
  //   styles: PropTypes.object,
  //   className: PropTypes.string,
  //   cursor: PropTypes.object,
  // };

  static defaultProps = {
    initialValue: '',
    language: 'javascript',
    theme: null,
    options: {},
    overrideServices: {},
    editorDidMount: noop,
    editorWillMount: noop,
    onChange: noop,
    isContentChanged: false,
    setIsContentChanged: noop,
    styles: {},
    className: '',
    cursor: DEF_CURSOR,
  };

  state = {
    width: 0,
    height: 0,
  };

  containerElement = null;
  editor = null;
  _subscription = null;
  _prevent_trigger_change_event = false;

  componentDidMount() {
    this.initMonaco();
  }

  adjustEditorSize() {
    if (this.containerElement && this.editor) {
      const { width, height } = this.state;
      const { clientWidth, clientHeight } = this.containerElement;
      if (width !== clientWidth && height !== clientHeight) {
        this.setState({
          height: clientHeight,
          width: clientWidth,
        });
      }
    }
  }

  setValidationError = () => {
    const { language, fileId } = this.props;

    if (language !== 'yaml') return;

    const { editor } = this;
    let model = editor.getModel(fileId);

    const yamlError = getYAMLError(editor.getValue());

    monaco.editor.setModelMarkers(model, 'jsyaml', [...(yamlError ? [getYAMLError(editor.getValue())] : [])]);

    this.validationError = yamlError;
  };

  throttledSetValidationError = throttle(this.setValidationError, 1000, { leading: false });

  componentDidUpdate(prevProps) {
    const { initialValue, language, fileId, theme, cursor, options } = this.props;

    const { editor } = this;

    if (fileId) {
      let model = getModelByFile(fileId);
      if (!model) {
        model = setModelByFile(fileId, language, initialValue);
      }

      if (editor.getModel() !== model) {
        editor.setModel(model);
        editor.focus();
      }

      if (prevProps.language !== language) {
        monaco.editor.setModelLanguage(model, language);
      }
    }

    if (prevProps.theme !== theme) {
      monaco.editor.setTheme(theme);
    }

    if (prevProps.options !== options) {
      editor.updateOptions(options);
    }
    if (prevProps.cursor !== cursor) {
      editor.setSelection(cursor);
      editor.revealLine(this.props.cursor.startLineNumber);
    }
  }

  componentWillUnmount() {
    this.destroyMonaco();
  }

  assignRef = (component) => {
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
    const { initialValue, language, theme, options, overrideServices } = this.props;
    if (this.containerElement) {
      // Before initializing monaco editor
      Object.assign(options, this.editorWillMount());

      this.editor = monaco.editor.create(
        this.containerElement,
        {
          value: initialValue,
          language: language || 'javascript',
          ...options,
          ...(theme ? { theme } : {}),
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
      editor.setSelection(this.props.cursor);
      editor.revealLine(this.props.cursor.startLineNumber);
    }

    this._subscription = editor.onDidChangeModelContent(() => {
      if (!this._prevent_trigger_change_event) {
        const currentValue = editor.getValue();

        const { initialValue, isContentChanged: wasChanged, setIsContentChanged } = this.props;

        const isChangedNow = currentValue !== initialValue;

        // signal when content was changed and returns to initial value, or vise versa
        if (!wasChanged && isChangedNow) {
          setIsContentChanged(true);
        } else if (wasChanged && !isChangedNow) {
          setIsContentChanged(false);
        }
      }

      this.throttledSetValidationError();
    });
  }

  render() {
    const { styles: styleObj, className } = this.props;

    return <div ref={this.assignRef} style={styleObj} className={className} />;
  }
}
