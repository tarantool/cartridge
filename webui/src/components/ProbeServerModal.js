// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import { Formik } from 'formik';
import {
  Alert,
  Button,
  LabeledInput,
  Modal,
  Text
} from '@tarantool.io/ui-kit';
import { probeServer } from 'src/store/actions/clusterPage.actions';
import {
  type ProbeServerActionCreator,
  setProbeServerModalVisible
} from 'src/store/actions/clusterPage.actions';

const styles = {
  formInner: css`
    margin-bottom: 16px;
  `,
  error: css`
    margin-bottom: 16px;
  `,
  text: css`
    display: block;
    margin-bottom: 16px;
    color: rgba(0, 0, 0, 0.65);
  `
};

type ProbeServerModalProps = {
  error?: string,
  probeServer: ProbeServerActionCreator,
  probeServerModalVisible: boolean,
  setProbeServerModalVisible: (visible: boolean) => void
};

class ProbeServerModal extends React.PureComponent<ProbeServerModalProps> {
  render() {
    const {
      error,
      probeServerModalVisible,
      setProbeServerModalVisible
    } = this.props;

    return (
      <React.Fragment>
        <Button
          className='meta-test__ProbeServerBtn'
          onClick={() => setProbeServerModalVisible(true)}
          text='Probe server'
        />
        <Formik
          initialValues={{
            uri: ''
          }}
          onSubmit={this.handleSubmit}
        >
          {({
            values,
            handleChange,
            handleSubmit,
            resetForm
          }) => (
            <Modal
              className='ProbeServerModal'
              footerControls={[
                <Button
                  className='meta-test__ProbeServerSubmitBtn'
                  type='submit'
                  intent='primary'
                  text='Submit'
                />
              ]}
              visible={probeServerModalVisible}
              title='Probe server'
              onClose={() => {
                setProbeServerModalVisible(false);
                resetForm();
              }}
              onSubmit={handleSubmit}
            >
              <div className={styles.formInner}>
                <Text className={styles.text}>
                  Probe a server if it wasn't discovered automatically by UDP broadcast.
                </Text>
                <LabeledInput
                  label='Server URI'
                  name='uri'
                  value={values.uri}
                  onChange={handleChange}
                  placeholder='Server URI, e.g. localhost:3301'
                />
              </div>
              {error && (
                <Alert className={cx(styles.error, 'ProbeServerModal_error')} type='error'>
                  <Text tag='span'>{error}</Text>
                </Alert>
              )}
            </Modal>
          )}
        </Formik>
      </React.Fragment>
    );
  }

  handleSubmit = ({ uri }) => {
    this.props.probeServer(uri);
  };
}

const mapStateToProps = state => ({
  error: state.clusterPage.probeServerError,
  probeServerModalVisible: state.ui.probeServerModalVisible
});

const mapDispatchToProps = {
  probeServer,
  setProbeServerModalVisible
};

export default connect(mapStateToProps, mapDispatchToProps)(ProbeServerModal);
