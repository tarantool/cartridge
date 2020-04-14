import { getErrorMessage } from '../../../api';
import * as R from 'ramda';
import { forward } from 'effector';

export default ({
  uploadClick,
  configPageMount,
  dropFiles,
  uploadFiles,
  submitConfigFx,
  $buttonAvailable,
  $files,
  $error,
  $success,
}) => {
  $files
    .on(dropFiles, (_, files) => files.slice(0, 1))
    .reset(submitConfigFx.done)
    .reset(configPageMount)
  $error
    .on(submitConfigFx.fail, (_, { error }) => getErrorMessage(error))
    .reset(submitConfigFx)
    .reset(dropFiles)
    .reset(configPageMount)

  $success
    .on(submitConfigFx.done, R.T)
    .reset(submitConfigFx)
    .reset(dropFiles)
    .reset(configPageMount)
  forward({from: uploadFiles, to: submitConfigFx})
}
