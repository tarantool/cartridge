// @flow
import {
  createStore,
  createEvent,
  createEffect,
  createStoreObject,
  sample
} from 'effector'
import type { Effect, Store } from 'effector'
import { uploadConfig } from '../request/clusterPage.requests';
import { getErrorMessage } from '../../api';

export const configPageMount = createEvent<mixed>('config page mount')
export const dropFiles = createEvent<Array<File>>('drop files')

export const submitConfig: Effect<Array<File>, boolean, Error> = createEffect('submit config', {
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

export const $files: Store<Array<File>> = createStore([])
  .on(dropFiles, (_, files) => files.slice(0, 1))
  .reset(submitConfig.done)
  .reset(configPageMount)

export const $error: Store<?string> = createStore(null)
  .on(submitConfig.fail, (_, { error }) => getErrorMessage(error))
  .reset(submitConfig)
  .reset(dropFiles)
  .reset(configPageMount)


export const $successfulFileName: Store<?string> = createStore(null)
  .on(
    submitConfig.done,
    (_, { params }) => {
      try {
        return params[0].name;
      } catch (err) {
        return null;
      }
    }
  )
  .reset(submitConfig)
  .reset(dropFiles)
  .reset(configPageMount)

export const $configForm = createStoreObject({
  files: $files,
  error: $error,
  successfulFileName: $successfulFileName,
  submitting: submitConfig.pending
})

sample({
  source: $files,
  clock: dropFiles,
  fn: files => files,
  target: submitConfig
})
