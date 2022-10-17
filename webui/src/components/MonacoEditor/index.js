import React from 'react';
import { noop, throttle } from 'lodash';

import { SS_CODE_EDITOR_CURSOR_POSITION } from 'src/constants';

import monaco from '../../misc/initMonacoEditor';
import { getModelByFile, setModelByFile } from '../../misc/monacoModelStorage';
import { getYAMLError } from '../../misc/yamlValidation';

const getCursorPosition = () => {
  try {
    const cursorPositionParsed = JSON.parse(sessionStorage.getItem(SS_CODE_EDITOR_CURSOR_POSITION));
    if (
      typeof cursorPositionParsed === 'object' &&
      typeof cursorPositionParsed.fileId === 'string' &&
      typeof cursorPositionParsed.lineNumber === 'number' &&
      typeof cursorPositionParsed.column === 'number'
    ) {
      const { fileId, lineNumber, column } = cursorPositionParsed;
      return { fileId, lineNumber, column };
    }
  } catch (error) {
    // no-empty
  }

  return null;
};

const storeCursorPosition = (fileId, lineNumber, column) => {
  try {
    sessionStorage.setItem(
      SS_CODE_EDITOR_CURSOR_POSITION,
      JSON.stringify({
        fileId: fileId,
        lineNumber: lineNumber || 0,
        column: column || 0,
      })
    );
  } catch (error) {
    // no-empty
  }
};

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
  };

  state = {
    width: 0,
    height: 0,
  };

  containerElement = null;
  editor = null;
  _subscriptions = [];
  _prevent_trigger_change_event = false;

  componentDidMount() {
    this.initMonaco();
  }

  focusAndFind() {
    try {
      if (this.editor) {
        this.editor.focus();
        this.editor.getAction('actions.find').run();
      }
    } catch (error) {
      // no-empty
    }
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
    const { initialValue, language, fileId, theme, options } = this.props;

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

      if (prevProps.fileId !== fileId) {
        storeCursorPosition(fileId);
      } else {
        const position = getCursorPosition();
        if (position && position.fileId === fileId) {
          editor.setPosition(position);
        }
      }
    }

    if (theme && prevProps.theme !== theme) {
      monaco.editor.setTheme(theme);
    }

    if (options && prevProps.options !== options) {
      editor.updateOptions(options);
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
    if (this._subscriptions.length > 0) {
      this._subscriptions.forEach((s) => s.dispose());
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

    const s1 = editor.onDidChangeCursorPosition((e) => {
      if (!e || !e.position) {
        return;
      }

      storeCursorPosition(this.props.fileId, e.position.lineNumber, e.position.column);
    });

    const s2 = editor.onDidChangeModelContent(() => {
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

    this._subscriptions.push(s1, s2);

    const position = getCursorPosition();
    if (position && position.fileId === this.props.fileId) {
      setTimeout(() => void editor.setPosition(position), 1);
    }
  }

  render() {
    const { styles: styleObj, className } = this.props;

    return <div ref={this.assignRef} style={styleObj} className={className} />;
  }
}
