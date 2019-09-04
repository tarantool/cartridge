// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import { Formik } from 'formik';
import InputText from 'src/components/InputText';
import Alert from 'src/components/Alert';
import Button from 'src/components/Button';
import Text from 'src/components/Text';
import PopupFooter from 'src/components/PopupFooter';
import { probeServer } from 'src/store/actions/clusterPage.actions';
import {
  type ProbeServerActionCreator,
  setProbeServerModalVisible
} from 'src/store/actions/clusterPage.actions';
import Modal from 'src/components/Modal';

const styles = {
  formInner: css`
    padding: 0 16px 16px;
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
        <Button onClick={() => setProbeServerModalVisible(true)} text='Probe server' />
        <Modal
          visible={probeServerModalVisible}
          title='Probe server'
          onClose={() => setProbeServerModalVisible(false)}
        >
          <Formik
            initialValues={{
              uri: ''
            }}
            onSubmit={this.handleSubmit}
          >
            {({
              values,
              handleChange,
              handleSubmit
            }) => (
              <form onSubmit={handleSubmit}>
                <div className={styles.formInner}>
                  {error && <Alert className={styles.error} type='error'><Text tag='span'>{error}</Text></Alert>}
                  <Text className={styles.text}>
                    Probe a server if it wasn't discovered automatically by UDP broadcast.
                  </Text>
                  <InputText
                    name='uri'
                    value={values.uri}
                    onChange={handleChange}
                    placeholder='Server URI, e.g. localhost:3301'
                  />
                </div>
                <PopupFooter
                  controls={(
                    <Button type='submit' intent='primary' text='Submit' />
                  )}
                />
              </form>
            )}
          </Formik>
        </Modal>
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
