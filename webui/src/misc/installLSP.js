import {
  MonacoServices, MonacoLanguageClient,
  CloseAction, ErrorAction, createConnection
} from 'monaco-languageclient'
import { listen } from 'vscode-ws-jsonrpc';
import RWSocket from 'reconnecting-websocket';
import rest from 'src/api/rest';

const sleep = ms => new Promise(r => setTimeout(r, ms))

function createLanguageClient(connection, language) {
  return new MonacoLanguageClient({
    name: 'Sample Language Client',
    clientOptions: {
      // use a language id as a document selector
      documentSelector: [language],
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

function createWebSocket(url: string): WebSocket {
  const socketOptions = {
    maxReconnectionDelay: 10000,
    minReconnectionDelay: 1000,
    reconnectionDelayGrowFactor: 1.3,
    connectionTimeout: 10000,
    maxRetries: Infinity,
    debug: false
  };
  return new RWSocket(url, [], socketOptions);
}

const serviceSymbol = '__service_inited__';

const createClient = (endpoint, language) => new Promise((resolve, reject) => {
  const { protocol, host } = window.location
  const usedProtocol = protocol === 'https' ? 'wss' : 'ws'
  const lspEndpoint = `${usedProtocol}://${host}${endpoint}`
  const socket = createWebSocket(
    lspEndpoint
  )

  let timeouted = false

  let timeout = setTimeout(() => {
    timeouted = true
    reject('timeout connection to client')
  }, 10000)

  listen({
    webSocket: socket,
    onConnection: connection => {
      if (timeouted) {
        return
      }
      // create and start the language client
      const languageClient = createLanguageClient(connection, language);
      const disposable = languageClient.start();
      connection.onClose(() => {
        disposable.dispose()
      });
      clearTimeout(timeout)
      resolve(async () => {
        await languageClient.stop()
        await disposable.dispose()
        socket.close()
      })
    },
    onError: console.error
  })
})

const checkEndpoint = async (endpoint, retry = false) => {
  try {
    const res = await rest.get(endpoint)
    return true
  } catch(e) {
    if (e && e.response && e.response.status) {
      switch(e.response.status) {
        case 401:
          return false
        case 501:
          return false
        default:
          return true
      }
    }
    if (retry) {
      return false
    }
    await sleep(5000)
    return await checkEndpoint(endpoint, true)
  }
}


export const installLSP = async (editor, language, endpoint) => {
  if (!editor[serviceSymbol]) {
    editor[serviceSymbol] = {}
    MonacoServices.install(editor)
  }

  const isEndpointAvailable = await checkEndpoint(endpoint)

  if (!isEndpointAvailable) return null

  try {
    if (!editor[serviceSymbol][language]) {
      editor[serviceSymbol][language] = {
        client: await createClient(endpoint, language),
        counter: 0
      }
    }

    editor[serviceSymbol][language].counter++

    return () => {
      const ln = editor[serviceSymbol][language]
      console.log(language, ln.counter)
      ln.counter--
      if (ln.counter === 0) {
        console.log('dispose', language)
        ln.client()
        editor[serviceSymbol][language] = null
      }
    }
  } catch(e) {
    console.error(e)
    return null
  }
}
