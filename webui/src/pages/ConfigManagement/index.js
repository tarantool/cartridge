// @flow

import React, { useEffect } from 'react'
import { css } from 'react-emotion'
import { TitledPanel } from '../../components/Panel'
import { Alert, Button, IconDownload, Text } from '@tarantool.io/ui-kit';
import UploadZone from '../../components/UploadZone';
import { useStore } from 'effector-react'
import { createConfigApi } from '../../store/effector/configUpload';

const { $configForm, dropFiles, uploadClick, configPageMount } = createConfigApi()

const { AppTitle } = window.tarantool_enterprise_core.components;

const styles = {
  downloadNotice: css`
    margin-bottom: 24px;
  `,
  container: css`
    padding: 24px 16px;
  `,
  title: css`
    margin-left: 16px;
    margin-bottom: 24px;
  `,
  error: css`
    font-size: 12px;
    line-height: 20px;
    color: #f5222d;
  `,
  uploadError: css`
    margin-bottom: 20px;
  `
}

export default () => {
  useEffect(configPageMount, [])

  const {
    files,
    error,
    success,
    buttonAvailable,
    submitting
  } = useStore($configForm)


  return <div className={styles.container}>
    <AppTitle title={'Configuration files'}/>
    <Text variant='h2' className={styles.title}>Configuration Management</Text>

    <TitledPanel
      className={css`margin-bottom: 16px`}
      title={<Text variant={'h3'}>Download configuration</Text>}
      content={
        <form action={process.env.REACT_APP_CONFIG_ENDPOINT} method={'get'}>
          <p className={styles.downloadNotice}>Current configuration can be downloaded here.</p>
          <Button
            className='meta-test__DownloadBtn'
            icon={IconDownload}
            intent={'secondary'}
            text={'Download'}
            type={'submit'}
          />
        </form>
      }
    />
    <TitledPanel
      title={<Text variant={'h3'}>Upload configuration</Text>}
      content={
        <React.Fragment>
          <UploadZone
            handler={dropFiles}
            name={'file'}
            label={'Choose config file to upload'}
            multiple={false}
            files={files}
          />
          {error && (
            <Alert type="error">
              <Text>{error}</Text>
            </Alert>
          )}
          {success && (
            <Alert type="success">
              <Text>Successfully uploaded</Text>
            </Alert>
          )}
          <Button
            intent={'secondary'}
            text={'Save'}
            disabled={!buttonAvailable}
            loading={submitting}
            onClick={uploadClick}
          />
        </React.Fragment>
      }
    />
  </div>
}
