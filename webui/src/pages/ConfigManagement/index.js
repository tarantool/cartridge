// @flow

import React, { useEffect } from 'react'
import { css, cx } from 'emotion';
import { connect } from 'react-redux';
import { Panel } from '../../components/Panel'
import {
  Alert,
  Button,
  IconAttach,
  IconDownload,
  PageLayout,
  Text
} from '@tarantool.io/ui-kit';
import UploadZone from '../../components/UploadZone';
import { useStore } from 'effector-react';
import { $configForm, dropFiles, configPageMount } from '../../store/effector/configUpload';
import { type State } from 'src/store/rootReducer';

const { AppTitle } = window.tarantool_enterprise_core.components;

const styles = {
  page: css`
    height: calc(100% - 69px);
  `,
  panel: css`
    display: flex;
    flex-direction: column;
    height: 600px;
  `,
  pageWithPane: css`
    height: calc(100% - 69px - 112px);
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
    margin-top: 15px;
    margin-bottom: 20px;
  `,
  uploadError: css`
    margin-bottom: 20px;
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
    success,
    buttonAvailable,
    submitting
  } = useStore($configForm)


  return (
    <PageLayout
      heading='Configuration Management'
      className={cx(
        styles.page,
        { [styles.pageWithPane]: isDemoPanelPresent }
      )}
      controls={[
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
          <Alert type='error'>
            {error}
          </Alert>
        )}
        {success && (
          <Alert type='success'>
            Successfully uploaded
          </Alert>
        )}
        <UploadZone
          className={styles.dropZone}
          disabled={!buttonAvailable}
          handler={dropFiles}
          name='file'
          label='Choose config file to upload'
          multiple={false}
          files={files}
        />
      </Panel>
    </PageLayout>
  );
};

const mapStateToProps = ({ app: { clusterSelf } }: State) => ({
  isDemoPanelPresent: !!clusterSelf && clusterSelf.demo_uri
});

export default connect(mapStateToProps)(ConfigManagement);
