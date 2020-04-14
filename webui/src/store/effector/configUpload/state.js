import {  } from 'effector'
import { createEvent } from 'effector';
import type { Effect, Store } from 'effector';
import { createEffect } from 'effector';
import { uploadConfig } from '../../request/clusterPage.requests';
import { createStore } from 'effector';
import { sample } from 'effector';
import { createStoreObject } from 'effector';


export default () => {
  const configPageMount = createEvent<any>('config page mount')
  const dropFiles = createEvent<Array<File>>('drop files')
  const uploadClick = createEvent<any>('upload click')

  const submitConfigFx: Effect<Array<File>, boolean, Error> = createEffect('submit config', {
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


  const $buttonAvailable: Store<boolean> = $files.map(files => files.length > 0)

  const $error: Store<?string> = createStore(null)

  const $success: Store<boolean> = createStore(false)

  const uploadFiles = sample({
    source: $files,
    clock: uploadClick,
    fn: files => files,
  })

  const $configForm = createStoreObject({
    files: $files,
    buttonAvailable: $buttonAvailable,
    error: $error,
    success: $success,
    submitting: submitConfigFx.pending
  })

  return {
    uploadClick,
    configPageMount,
    dropFiles,
    submitConfigFx,
    $buttonAvailable,
    uploadFiles,
    $files,
    $error,
    $success,
    $configForm
  }
}
