// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  createDomain,
  sample
} from 'effector'
import type { Effect, Store } from 'effector'
import { uploadConfig } from '../request/clusterPage.requests';
import { getErrorMessage } from '../../api';
import * as R from 'ramda'

export const createConfigApi = () => {
  const configPageMount = createEvent<any>('config page mount')
  const dropFiles = createEvent<Array<File>>('drop files')
  const uploadClick = createEvent<any>('upload click')

  const submitConfig: Effect<Array<File>, boolean, Error> = createEffect('submit config', {
    handler: async files => {
      const data = new FormData()
      if (files.length < 1) {
        throw new Error('no files')
      }
      data.append('file', files[0])
      await uploadConfig({ data })
      return true
    }
  })

  const $files: Store<Array<File>> = createStore([])
    .on(dropFiles, (_, files) => files.slice(0, 1))
    .reset(submitConfig.done)
    .reset(configPageMount)


  const $buttonAvailable: Store<boolean> = $files.map(files => files.length > 0)

  const $error: Store<?string> = createStore(null)
    .on(submitConfig.fail, (_, { error }) => getErrorMessage(error))
    .reset(submitConfig)
    .reset(dropFiles)
    .reset(configPageMount)


  const $success: Store<boolean> = createStore(false)
    .on(submitConfig.done, R.T)
    .reset(submitConfig)
    .reset(dropFiles)
    .reset(configPageMount)

  const $configForm = createStoreObject({
    files: $files,
    buttonAvailable: $buttonAvailable,
    error: $error,
    success: $success,
    submitting: submitConfig.pending
  })

  sample({
    source: $files,
    clock: uploadClick,
    fn: files => files,
    target: submitConfig
  })

  return {
    configPageMount,
    dropFiles,
    uploadClick,
    $configForm
  }
}

