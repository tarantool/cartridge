import * as monaco from 'monaco-editor/esm/vs/editor/edcore.main.js';
import PropTypes from 'prop-types';
import React from 'react';
import { noop, throttle } from 'lodash';
import { subscribeOnTargetEvent } from '../../misc/eventHandler';
import { getModelByFile, setModelByFile } from '../../misc/monacoModelStorage';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution';
import 'monaco-editor/esm/vs/basic-languages/yaml/yaml.contribution';
import 'monaco-editor/esm/vs/basic-languages/lua/lua.contribution';

import 'monaco-editor/esm/vs/basic-languages/html/html.contribution';
import {
  MonacoServices, MonacoLanguageClient,
  CloseAction, ErrorAction, createConnection
} from 'monaco-languageclient'
import { listen } from 'vscode-ws-jsonrpc';
import { getLanguageService, TextDocument } from 'vscode-json-languageservice';
import { MonacoToProtocolConverter, ProtocolToMonacoConverter } from 'monaco-languageclient/lib/monaco-converter';
import './setDefaultTheme';

const MODEL_URI = 'inmemory://model.json'
const MONACO_URI = monaco.Uri.parse(MODEL_URI);

function createDocument(model) {
  return TextDocument.create(MODEL_URI, model.getModeId(), model.getVersionId(), model.getValue());
}

const m2p = new MonacoToProtocolConverter();
const p2m = new ProtocolToMonacoConverter();

function createDependencyProposals() {
  // returning a static list of proposals, not even looking at the prefix (filtering is done by the Monaco editor),
  // here you could do a server side lookup
  return [
    {
      label: '"lodash"',
      kind: monaco.languages.CompletionItemKind.Function,
      documentation: 'The Lodash library exported as Node.js modules.',
      insertText: '"lodash": "*"'
    },
    {
      label: '"express"',
      kind: monaco.languages.CompletionItemKind.Function,
      documentation: 'Fast, unopinionated, minimalist web framework',
      insertText: '"express": "*"'
    },
    {
      label: '"mkdirp"',
      kind: monaco.languages.CompletionItemKind.Function,
      documentation: 'Recursively mkdir, like <code>mkdir -p</code>',
      insertText: '"mkdirp": "*"'
    }
  ];
}


monaco.languages.registerCompletionItemProvider('lua', {
  provideCompletionItems: function(model, position) {
    // find out if we are completing a property in the 'dependencies' object.
    var textUntilPosition = model.getValueInRange({
      startLineNumber: 1,
      startColumn: 1,
      endLineNumber: position.lineNumber,
      endColumn: position.column,
    });
    var match = textUntilPosition.match(/"dependencies"\s*:\s*\{\s*("[^"]*"\s*:\s*"[^"]*"\s*,\s*)*([^"]*)?$/);
    var suggestions = match ? createDependencyProposals() : [];
    return {
      suggestions: suggestions
    };
  }
});


function createWebSocket(url: string): WebSocket {
  const socketOptions = {
    maxReconnectionDelay: 10000,
    minReconnectionDelay: 1000,
    reconnectionDelayGrowFactor: 1.3,
    connectionTimeout: 10000,
    maxRetries: Infinity,
    debug: false
  };
  return new WebSocket(url, [], socketOptions);
}
const { protocol, hostname, port } = window.location;

const socket = createWebSocket(
  `${protocol === 'https' ? 'wss' : 'ws' }://${hostname}:${8081}/admin/lsp`
)

function createLanguageClient(connection) {
  return new MonacoLanguageClient({
    name: 'Sample Language Client',
    clientOptions: {
      // use a language id as a document selector
      documentSelector: ['lua'],
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

      // monaco.languages.registerCompletionItemProvider('lua', {
      //   provideCompletionItems(model, position, context, token) {
      //     const document = createDocument(model);
      //     const wordUntil = model.getWordUntilPosition(position);
      //     const defaultRange = new monaco.Range(
      //       position.lineNumber, wordUntil.startColumn, position.lineNumber, wordUntil.endColumn
      //     );
      //     const jsonDocument = jsonService.parseJSONDocument(document);
      //     return jsonService.doComplete(document, m2p.asPosition(
      //       position.lineNumber, position.column), jsonDocument
      //     ).then((list) => {
      //       return p2m.asCompletionResult(list, defaultRange);
      //     });
      //   },
      //
      //   resolveCompletionItem(model, position, item, token): monaco.languages
      //   .CompletionItem | monaco.Thenable<monaco.languages.CompletionItem> {
      //     return jsonService.doResolve(m2p.asCompletionItem(item))
      //     .then(result => p2m.asCompletionItem(result, item.range));
      //   }
      // });

      listen({
        webSocket: socket,
        onConnection: connection => {
          // create and start the language client
          const languageClient = createLanguageClient(connection);
          const disposable = languageClient.start();
          console.log('language client', languageClient)
          connection.onClose(() => disposable.dispose());
        }
      })
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
