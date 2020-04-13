// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import { getGraphqlErrorMessage } from 'src/api/graphql';
import { changeFailover, setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';
import {
  Alert,
  Button,
  FormField,
  Input,
  InputPassword,
  LabeledInput,
  Modal,
  RadioButton,
  Text
} from '@tarantool.io/ui-kit';
import type { FailoverApi } from 'src/generated/graphql-typing.js';

const styles = {
  field: css`
    margin-left: 16px;
    margin-right: 16px;
  `,
  radioFieldItem: css`
    margin-bottom: 8px;
  `,
  borderedRadio: css`
    padding-bottom: 8px;
    border-bottom: solid 1px #e8e8e8;
  `,
  radio: css`
    align-items: flex-start;
    margin-bottom: 8px;

    & > input + div {
      margin-top: 3px;
    }
  `,
  radioLabel: css`
    display: block;
    margin-bottom: 8px;
  `,
  radioDescription: css`
    opacity: 0.7;
  `,
  inputs: css`
    display: flex;
  `,
  inputField: css`
    width: 188px;
    margin-left: 16px;
    margin-right: 16px;
  `
}

type FailoverModalProps = FailoverApi & {
  dispatch: (action: FSA) => void,
  changeFailover: (failover: FailoverApi) => void,
  setVisibleFailoverModal: (visible: boolean) => void,
  error?: string | Error
}

type FailoverModalState = {
  mode: string,
  uri: string,
  password: string
}

class FailoverModal extends React.Component<FailoverModalProps, FailoverModalState> {
  constructor(props) {
    super(props);

    const { mode, tarantool_params } = props;

    this.state = {
      mode,
      uri: (tarantool_params && tarantool_params.uri) || '',
      password: (tarantool_params && tarantool_params.password) || ''
    }
  }

  handleModeChange = (mode: string) => this.setState({ mode });

  handleURIChange = (e: InputEvent) => {
    if (e.target instanceof HTMLInputElement) {
      this.setState({ uri: e.target.value });
    }
  }

  handlePasswordChange = (e: InputEvent) => {
    if (e.target instanceof HTMLInputElement) {
      this.setState({ password: e.target.value });
    }
  }

  handleSubmit = (e: Event) => {
    e.preventDefault();

    const { mode, uri, password } = this.state;

    this.props.changeFailover({
      mode,
      tarantool_params: mode === 'stateful'
        ? { uri, password }
        : null,
      state_provider: mode === 'stateful' ? 'tarantool' : null
    });
  }

  render() {
    const { setVisibleFailoverModal, error } = this.props;

    const {
      mode,
      uri,
      password
    } = this.state;

    return (
      <Modal
        className='meta-test__FailoverModal'
        title='Failover control'
        onClose={() => setVisibleFailoverModal(false)}
        onSubmit={this.handleSubmit}
        footerControls={[
          <Button
            className='meta-test__CancelButton'
            onClick={() => setVisibleFailoverModal(false)}
          >
            Cancel
          </Button>,
          <Button
            className='meta-test__SubmitButton'
            intent='primary'
            type='submit'
          >
            Apply
          </Button>
        ]}
      >
        <FormField label='Failover mode' className={styles.field} itemClassName={styles.radioFieldItem}>
          <RadioButton
            className={cx(styles.radio, styles.borderedRadio, 'meta-test__disableRadioBtn')}
            checked={mode === 'disabled'}
            onChange={() => this.handleModeChange('disabled')}
          >
            <div>
              <Text className={styles.radioLabel}>Disabled</Text>
              <Text className={styles.radioDescription} tag='p'>
                The leader is the first instance according to topology configuration.
                No automatic decisions are taken.
              </Text>
            </div>
          </RadioButton>
          <RadioButton
            className={cx(styles.radio, styles.borderedRadio, 'meta-test__eventualRadioBtn')}
            checked={mode === 'eventual'}
            onChange={() => this.handleModeChange('eventual')}
          >
            <div>
              <Text className={styles.radioLabel}>Eventual</Text>
              <Text className={styles.radioDescription} tag='p'>
                The leader isnt't elected consistently.
                Every instance thinks the leader is the first healthy server in the replicaset.
                The instance health is determined according to the membership status (the SWIM protocol).
              </Text>
            </div>
          </RadioButton>
          <RadioButton
            className={cx(styles.radio, 'meta-test__statefulRadioBtn')}
            checked={mode === 'stateful'}
            onChange={() => this.handleModeChange('stateful')}
          >
            <div>
              <Text className={styles.radioLabel}>Stateful</Text>
              <Text className={styles.radioDescription} tag='p'>
                Leader appointments are polled from the external state provider.
                Decisions are taken by one of the instances with the failover-coordinator role enabled.
              </Text>
            </div>
          </RadioButton>
        </FormField>
        <div className={styles.inputs}>
          <LabeledInput className={styles.inputField} label='State provider URI'>
            <Input
              className='meta-test__stateboardURI'
              value={uri}
              disabled={mode !== 'stateful'}
              onChange={this.handleURIChange}
            />
          </LabeledInput>
          <LabeledInput className={styles.inputField} label='Password'>
            <InputPassword
              className='meta-test__stateboardPassword'
              value={password}
              disabled={mode !== 'stateful'}
              onChange={this.handlePasswordChange}
            />
          </LabeledInput>
        </div>
        {error && (
          <Alert type="error">
            <Text variant="basic">{error}</Text>
          </Alert>
        )}
      </Modal>
    );
  }
}

const mapStateToProps = ({
  app: { failover_params },
  clusterPage: { changeFailoverRequestStatus: { error } }
}) => ({
  ...failover_params,
  error: error && getGraphqlErrorMessage(error)
});

const mapDispatchToProps = { changeFailover, setVisibleFailoverModal };

export default connect(mapStateToProps, mapDispatchToProps)(FailoverModal);
