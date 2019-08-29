import * as React from 'react'
import { css, cx } from 'react-emotion'
import { connect } from 'react-redux'
import { getErrorMessage } from '../../api';
import Alert from '../../components/Alert';
import Text from '../../components/Text'
import Panel, { TitledPanel } from '../../components/Panel'
import Button from '../../components/Button'
import { IconDownload } from '../../components/Icon/icons/IconDownload';
import UploadZone from '../../components/UploadZone';
import { uploadConfig } from '../../store/actions/clusterPage.actions';

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

class ConfigManagement extends React.Component {
  state = {
    files: [],
    error: null
  }

  handleUpload = e => {
    e.preventDefault()
    if (this.state.files.length > 0) {
      const data = new FormData();
      data.append('file', this.state.files[0]);

      this.props.dispatch(uploadConfig({ data }));
    } else {
      this.setState(() => ({ error: 'You should select file for upload' }))
    }
  }

  handleDrop = files => {
    this.setState(() => ({ files, error: null }))
  }

  render() {
    const { error, files } = this.state
    const { uploadConfigRequestStatus } = this.props;


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
              icon={IconDownload}
              intent={'secondary'}
              text={'Download'}
            />
          </form>
        }
      />
      <TitledPanel
        title={<Text variant={'h3'}>Upload configuration</Text>}
        content={
          <React.Fragment>
            <UploadZone
              handler={this.handleDrop}
              name={'file'}
              label={'Choose yaml config file to upload'}
            />
            {error && (
              <Alert type="error">
                <Text>{error}</Text>
              </Alert>
            )}
            {uploadConfigRequestStatus.error && (
              <Alert type="error" className={styles.uploadError}>
                <Text>{getErrorMessage(uploadConfigRequestStatus.error)}</Text>
              </Alert>
            )}
            <Button
              intent={'secondary'}
              text={'Save'}
              disabled={files.length === 0}
              onClick={this.handleUpload}
            />
          </React.Fragment>
        }
      />
    </div>
  }
}

export default connect()(ConfigManagement)
