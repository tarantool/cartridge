// @flow

import React, { useEffect } from 'react'
import { css } from 'emotion';
import { Panel } from '../../components/Panel'
import {
  Alert,
  Button,
  IconAttach,
  IconDownload,
  Text,
  UploadZone,
  colors
} from '@tarantool.io/ui-kit';
import { PageLayout } from 'src/components/PageLayout';
import { useStore } from 'effector-react';
import { $configForm, dropFiles, configPageMount } from '../../store/effector/configUpload';

const { AppTitle } = window.tarantool_enterprise_core.components;

const styles = {
  panel: css`
    display: flex;
    flex-direction: column;
    height: 600px;
  `,
  panelNote: css`
    margin-top: 6px;
    margin-bottom: 15px;
  `,
  dropZone: css`
    flex-grow: 1;
  `,
  title: css`
    margin-left: 16px;
    margin-bottom: 24px;
  `,
  alert: css`
    margin-top: 0;
    margin-bottom: 20px;
  `,
  attachIcon: css`
    margin-right: 6px;
    margin-left: 30px;
    fill: ${colors.intentSuccess};
  `
}

type ConfigManagementProps = {
  isDemoPanelPresent?: boolean
}

const ConfigManagement = ({ isDemoPanelPresent }: ConfigManagementProps) => {
  useEffect(configPageMount, [])

  const {
    files,
    error,
    successfulFileName,
    submitting
  } = useStore($configForm)


  return (
    <PageLayout
      heading='Configuration Management'
      topRightControls={[
        <a href={process.env.REACT_APP_CONFIG_ENDPOINT}>
          <Button
            className='meta-test__DownloadBtn'
            icon={IconDownload}
            intent='primary'
            size='l'
            text='Current configuration'
          />
        </a>
      ]}
    >
      <AppTitle title='Configuration files'/>
      <Panel className={styles.panel}>
        <Text variant='h2'>Upload configuration</Text>
        <Text className={styles.panelNote} tag='p'>New configuration can be uploaded here.</Text>
        {error && (
          <Alert className={styles.alert} type='error'>
            {error}
          </Alert>
        )}
        {successfulFileName && (
          <Alert className={styles.alert} type='success'>
            New configuration uploaded successfully.
            <IconAttach className={styles.attachIcon} />
            {successfulFileName}
          </Alert>
        )}
        <UploadZone
          className={styles.dropZone}
          handler={dropFiles}
          name='file'
          label='Choose config file to upload'
          loading={submitting}
          multiple={false}
          files={files}
        />
      </Panel>
    </PageLayout>
  );
};

export default ConfigManagement;
