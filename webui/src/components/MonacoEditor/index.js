import * as monaco from 'monaco-editor/esm/vs/editor/editor.api';
import PropTypes from 'prop-types';
import React from 'react';
import { noop, throttle } from 'lodash';
import ReconnectingWebSocket from 'reconnecting-websocket';
import { subscribeOnTargetEvent } from '../../misc/eventHandler';
import { getModelByFile, setModelByFile } from '../../misc/monacoModelStorage';
import { getLanguageService, TextDocument } from 'vscode-json-languageservice';
import { MonacoToProtocolConverter, ProtocolToMonacoConverter } from 'monaco-languageclient/lib/monaco-converter';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution';
import 'monaco-editor/esm/vs/basic-languages/yaml/yaml.contribution';
import 'monaco-editor/esm/vs/basic-languages/lua/lua.contribution';

import 'monaco-editor/esm/vs/basic-languages/html/html.contribution';
import {
  MonacoServices, MonacoLanguageClient,
  CloseAction, ErrorAction, createConnection
} from 'monaco-languageclient'
import { listen } from 'vscode-ws-jsonrpc';


function createWebSocket(url: string): WebSocket {
  const socketOptions = {
    maxReconnectionDelay: 10000,
    minReconnectionDelay: 1000,
    reconnectionDelayGrowFactor: 1.3,
    connectionTimeout: 10000,
    maxRetries: Infinity,
    debug: false
  };
  return new ReconnectingWebSocket(url, [], socketOptions);
}
const socket = createWebSocket('http://localhost:2089/')

function createLanguageClient(connection) {
  return new MonacoLanguageClient({
    name: 'Sample Language Client',
    clientOptions: {
      // use a language id as a document selector
      documentSelector: ['js'],
      // disable the default error handler
      errorHandler: {
        error: () => ErrorAction.Continue,
        closed: () => CloseAction.DoNotRestart
      }
    },
    // create a language client connection from the JSON RPC connection on demand
    connectionProvider: {
      get: (errorHandler, closeHandler) => {
        return Promise.resolve(createConnection(connection, errorHandler, closeHandler))
      }
    }
  });
}

listen({
  webSocket: socket,
  onConnection: connection => {
    // create and start the language client
    const languageClient = createLanguageClient(connection);
    const disposable = languageClient.start();
    connection.onClose(() => disposable.dispose());
  }
})

const DEF_CURSOR = {}

export default class MonacoEditor extends React.Component {
  static propTypes = {
    value: PropTypes.string,
    fileId: PropTypes.string,
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
  _prevent_trigger_change_event = false;

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
      value, language, fileId, theme, cursor, options
    } = this.props;

    console.log(this.editor)

    const { editor } = this;
    let model = editor.getModel(fileId)
    if (prevProps.fileId !== fileId) {
      const existedModel = getModelByFile(fileId)
      if (!existedModel) {
        model = setModelByFile(fileId, language, value)
      } else {
        model = existedModel
      }
      editor.setModel(model)
      editor.focus()
    } else {
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
          language: 'javascript',
          ...options,
          ...(theme ? { theme } : {})
        },
        overrideServices
      );
      MonacoServices.install(this.editor)
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
      if (!this._prevent_trigger_change_event) {
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
