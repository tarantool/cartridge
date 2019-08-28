// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import { Formik } from 'formik';
import InputText from 'src/components/InputText';
import Button from 'src/components/Button';
import PopupFooter from 'src/components/PopupFooter';
import { probeServer } from 'src/store/actions/clusterPage.actions';
import type { ProbeServerActionCreator } from 'src/store/actions/clusterPage.actions';
import Modal from 'src/components/Modal';

const styles = {
  formInner: css`
    padding: 16px;
  `
};

type ProbeServerModalProps = {
  error?: string,
  probeServer: ProbeServerActionCreator,
  onRequestClose: () => void
};

class ProbeServerModal extends React.PureComponent<ProbeServerModalProps> {
  render() {
    const {
      error,
      onRequestClose
    } = this.props;

    return (
      <Modal
        visible={true}
        title='Probe server'
        onClose={onRequestClose}
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
              {error}
              <div className={styles.formInner}>
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
    );
  }

  handleSubmit = ({ uri }) => {
    this.props.probeServer(uri);
  };
}

const mapStateToProps = state => ({
  error: state.clusterPage.probeServerError
});

const mapDispatchToProps = {
  probeServer
};

export default connect(mapStateToProps, mapDispatchToProps)(ProbeServerModal);
