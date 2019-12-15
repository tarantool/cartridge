// @flow

import * as React from 'react'
import { installLSP } from '../misc/installLSP';
import monaco from '../misc/initMonacoEditor';
import * as R from 'ramda'

type LSPHoCProps = {
  lspEndpoints: []
}

type LSPHocState = {
  lspStatus: {
    [string]: {
      enabled: boolean,
      dispose?: Function,
    }
  }
}

function getDisplayName(WrappedComponent) {
  return WrappedComponent.displayName || WrappedComponent.name || 'Component';
}

export default (WrappedComponent: React.ComponentType<any>) => {

  class LSPHoC extends React.Component<LSPHoCProps, LSPHocState> {
    static defaultProps = {
      lspEndpoints: []
    }
    static displayName = `LSPHoC<${getDisplayName(WrappedComponent)}>`


    state = {
      lspStatus: {}
    }


    componentDidMount(): void {
      this.props.lspEndpoints.forEach(
        async ({ endpoint, language }) => {

          const disposeLanguage = await installLSP(monaco.editor, language, endpoint)
          if (disposeLanguage) {
            this.setState(({ lspStatus }) => ({
              lspStatus: {
                ...lspStatus,
                [language]: {
                  enabled: true,
                  dispose: disposeLanguage
                }
              }
            }))
          }
        }
      )
    }

    componentDidUpdate(prevProps: LSPHoCProps, prevState: LSPHocState): void {

      const lspEndpoints = this.props.lspEndpoints
      const prevLspEndpoints = prevProps.lspEndpoints

      const removed = R.differenceWith(R.eqProps('language'), prevLspEndpoints, lspEndpoints)
      const added = R.differenceWith(R.eqProps('language'), lspEndpoints, prevLspEndpoints)

      const removedLanguages = removed.map(R.prop('language'))

      for (const lang of removedLanguages) {
        const langStatus = this.state.lspStatus[lang]
        if (langStatus.enabled && langStatus.dispose) {
          langStatus.dispose()
        }
        this.setState(({ lspStatus }) => ({
          lspStatus: R.filter(R.equals(R.compose(R.not, langStatus)), lspStatus)
        }))
      }

      added.forEach(
        async ({ endpoint, language }) => {
          const disposeLanguage = await installLSP(monaco.editor, language, endpoint)
          if (disposeLanguage) {
            this.setState(({ lspStatus }) => ({
              lspStatus: {
                ...lspStatus,
                [language]: {
                  enabled: true,
                  dispose: disposeLanguage
                }
              }
            }))
          }
        }
      )
    }

    componentWillUnmount() {
      for (const lang of Object.keys(this.state.lspStatus)) {
        const langStatus = this.state.lspStatus[lang]
        if (langStatus.enabled && langStatus.dispose) {
          langStatus.dispose()
        }
      }
    }

    render() {
      const { lspEndpoints, ...props } = this.props

      return <WrappedComponent {...props} />
    }
  }

  return LSPHoC
}
