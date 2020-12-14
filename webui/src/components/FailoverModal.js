// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import { getGraphqlErrorMessage } from 'src/api/graphql';
import { changeFailover, setVisibleFailoverModal } from 'src/store/actions/clusterPage.actions';
import {
  Alert,
  Button,
  DropdownItem,
  FormField,
  IconChevron,
  InputPassword,
  LabeledInput,
  Modal,
  RadioButton,
  Text,
  TextArea,
  colors,
  withDropdown,
  Checkbox
} from '@tarantool.io/ui-kit';
import { FAILOVER_STATE_PROVIDERS } from 'src/constants';
import type { FailoverApi, MutationApiclusterFailover_ParamsArgs } from 'src/generated/graphql-typing.js';

const styles = {
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
    flex-wrap: wrap;
    margin-left: -16px;
    margin-right: -16px;
  `,
  inputField: css`
    flex-shrink: 0;
    width: calc(50% - 32px);
    margin-left: 16px;
    margin-right: 16px;
    box-sizing: border-box;
  `,
  selectBox: css`
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
  `,
  selectBoxIcon: css`
    fill: ${colors.intentBase};
    transform: rotate(180deg);
  `,
  infoInlineCode: css`
    color: inherit;
    font-size: inherit;
  `
}

const messages = {
  failoverTimeout: 'Timeout (in seconds), used by membership to mark suspect members as dead (default: 20)',
  // eslint-disable-next-line max-len
  fencingEnabled: 'Abandon leadership when both the state provider quorum and at least one replica are lost (default: false)',
  fencingTimeout: 'Time (in seconds) to actuate fencing after the check fails (default: 10)',
  fencingPause: 'The period (in seconds) of performing the check (default: 2)'
};

const DropdownButton = withDropdown(Button);

const SelectBox = ({
  className,
  values = [],
  value,
  onChange,
  disabled
}) => (
  <DropdownButton
    label='State provider'
    className={cx(styles.selectBox, className)}
    disabled={disabled}
    iconRight={() => <IconChevron className={styles.selectBoxIcon} />}
    text={value || values[0] || ''}
    items={values.map(value => (
      <DropdownItem onClick={() => onChange(value)}>{value}</DropdownItem>
    ))}
  />
);


type FailoverModalProps = FailoverApi & {
  dispatch: (action: FSA) => void,
  changeFailover: (failover: MutationApiclusterFailover_ParamsArgs) => void,
  setVisibleFailoverModal: (visible: boolean) => void,
  error?: string | Error
}

type FailoverModalState = {
  failover_timeout: number,
  fencing_enabled: bool,
  fencing_timeout: number,
  fencing_pause: number,
  mode: string,
  state_provider?: string,
  tarantool_params: {|
    uri: string,
    password: string
  |},
  etcd2_params: {
    lock_delay: ?string,
    username: ?string,
    password: ?string,
    prefix: ?string,
    endpoints: ?string
  }
}

class FailoverModal extends React.Component<FailoverModalProps, FailoverModalState> {
  constructor(props) {
    super(props);

    const {
      failover_timeout,
      fencing_enabled,
      fencing_timeout,
      fencing_pause,
      mode,
      tarantool_params,
      etcd2_params,
      state_provider
    } = props;

    this.state = {
      failover_timeout: failover_timeout.toString(),
      fencing_enabled,
      fencing_timeout: fencing_timeout.toString(),
      fencing_pause: fencing_pause.toString(),
      mode,
      tarantool_params: {
        uri: (tarantool_params && tarantool_params.uri) || '',
        password: (tarantool_params && tarantool_params.password) || ''
      },
      state_provider: state_provider || 'tarantool',
      etcd2_params: {
        endpoints: (etcd2_params && etcd2_params.endpoints && etcd2_params.endpoints.join('\n')) || '',
        password: (etcd2_params && etcd2_params.password) || '',
        lock_delay: ((etcd2_params && etcd2_params.lock_delay) || '').toString(),
        username: (etcd2_params && etcd2_params.username) || '',
        prefix: (etcd2_params && etcd2_params.prefix) || ''
      }
    }
  }

  handleModeChange = (mode: string) => this.setState({ mode });

  handleStateProviderChange = (state_provider: string) => this.setState({ state_provider });

  handleFencingToggle = () => this.setState(({ fencing_enabled }) => ({ fencing_enabled: !fencing_enabled }));

  handleInputChange = (fieldPath: [string, ?string]) => ({ target }: InputEvent) => {

    if (target && (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement)) {
      this.setState(prevState => ({
        [fieldPath[0]]: fieldPath[1]
          ? {
            ...prevState[fieldPath[0]],
            [fieldPath[1]]: target.value
          }
          : target.value
      }));
    }
  }

  handleSubmit = (e: Event) => {
    e.preventDefault();

    const {
      failover_timeout,
      fencing_enabled,
      fencing_timeout,
      fencing_pause,
      mode,
      etcd2_params,
      tarantool_params,
      state_provider
    } = this.state;

    const etcd2LockDelay = parseFloat(etcd2_params.lock_delay);

    this.props.changeFailover({
      failover_timeout: parseFloat(failover_timeout),
      fencing_enabled,
      fencing_timeout: parseFloat(fencing_timeout),
      fencing_pause: parseFloat(fencing_pause),
      mode,
      tarantool_params: mode === 'stateful' && state_provider === 'tarantool'
        ? tarantool_params
        : null,
      etcd2_params: mode === 'stateful' && state_provider === 'etcd2'
        ? {
          prefix: etcd2_params.prefix || null,
          username: etcd2_params.username || null,
          password: etcd2_params.password || null,
          endpoints: etcd2_params.endpoints ? etcd2_params.endpoints.split('\n') : null,
          lock_delay: isNaN(etcd2LockDelay) ? null : etcd2LockDelay
        }
        : null,
      state_provider: mode === 'stateful' ? state_provider : null
    });
  }

  render() {
    const { setVisibleFailoverModal, error } = this.props;

    const {
      mode,
      failover_timeout,
      fencing_enabled,
      fencing_pause,
      fencing_timeout,
      state_provider,
      tarantool_params,
      etcd2_params
    } = this.state;

    const disableFencingParams = mode !== 'stateful' || !fencing_enabled;

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
            size='l'
          >
            Cancel
          </Button>,
          <Button
            className='meta-test__SubmitButton'
            intent='primary'
            type='submit'
            size='l'
          >
            Apply
          </Button>
        ]}
      >
        <LabeledInput
          label='Failover timeout'
          className='meta-test__failoverTimeout'
          error={failover_timeout && !failover_timeout.match(/^\d+(\.\d+)*$/)}
          value={failover_timeout}
          onChange={this.handleInputChange(['failover_timeout'])}
          info={messages.failoverTimeout}
        />
        <FormField label='Failover mode' itemClassName={styles.radioFieldItem}>
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
                The leader isn't elected consistently.
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
        <LabeledInput
          label='State provider'
          className='meta-test__stateProviderChoice'
          inputComponent={SelectBox}
          values={FAILOVER_STATE_PROVIDERS}
          value={state_provider}
          disabled={mode !== 'stateful'}
          onChange={this.handleStateProviderChange}
        />
        {state_provider === 'tarantool' && (
          <div className={styles.inputs}>
            <LabeledInput
              className={styles.inputField}
              label='State provider URI'
              inputClassName='meta-test__stateboardURI'
              value={tarantool_params.uri}
              disabled={mode !== 'stateful'}
              onChange={this.handleInputChange(['tarantool_params', 'uri'])}
            />
            <LabeledInput
              className={styles.inputField}
              label='Password'
              inputComponent={InputPassword}
              inputClassName='meta-test__stateboardPassword'
              value={tarantool_params.password}
              disabled={mode !== 'stateful'}
              onChange={this.handleInputChange(['tarantool_params', 'password'])}
            />
          </div>
        )}
        {state_provider === 'etcd2' && (
          <>
            <div className={styles.inputs}>
              <LabeledInput
                className={styles.inputField}
                label='Username'
                inputClassName='meta-test__etcd2Username'
                value={etcd2_params.username}
                disabled={mode !== 'stateful'}
                onChange={this.handleInputChange(['etcd2_params', 'username'])}
              />
              <LabeledInput
                className={styles.inputField}
                label='Password'
                inputClassName='meta-test__etcd2Password'
                inputComponent={InputPassword}
                value={etcd2_params.password}
                disabled={mode !== 'stateful'}
                onChange={this.handleInputChange(['etcd2_params', 'password'])}
              />
              <LabeledInput
                className={styles.inputField}
                label='Delay, seconds'
                inputClassName='meta-test__etcd2LockDelay'
                value={etcd2_params.lock_delay}
                disabled={mode !== 'stateful'}
                onChange={this.handleInputChange(['etcd2_params', 'lock_delay'])}
              />
              <LabeledInput
                className={styles.inputField}
                label='Prefix'
                inputClassName='meta-test__etcd2Prefix'
                value={etcd2_params.prefix}
                disabled={mode !== 'stateful'}
                onChange={this.handleInputChange(['etcd2_params', 'prefix'])}
              />
            </div>
            <LabeledInput
              label='etcd2 endpoints'
              className='meta-test__etcd2Endpoints'
              inputComponent={TextArea}
              value={etcd2_params.endpoints}
              disabled={mode !== 'stateful'}
              rows={5}
              onChange={this.handleInputChange(['etcd2_params', 'endpoints'])}
            />
          </>
        )}
        <FormField label='Fencing'>
          <Checkbox
            className={cx(styles.radio, 'meta-test__statefulRadioBtn')}
            disabled={mode !== 'stateful'}
            checked={fencing_enabled}
            onChange={() => this.handleFencingToggle()}
          >
            <div>
              <Text className={styles.radioLabel}>Enable</Text>
              <Text className={styles.radioDescription} tag='p'>
                {messages.fencingEnabled}
              </Text>
            </div>
          </Checkbox>
        </FormField>
        <LabeledInput
          label='Fencing timeout'
          className='meta-test__fencingTimeout'
          disabled={disableFencingParams}
          error={!disableFencingParams && (fencing_timeout && !fencing_timeout.match(/^\d+(\.\d+)*$/))}
          info={messages.fencingTimeout}
          value={fencing_timeout}
          onChange={this.handleInputChange(['fencing_timeout'])}
        />
        <LabeledInput
          label='Fencing pause'
          className='meta-test__fencingPause'
          disabled={disableFencingParams}
          error={!disableFencingParams && (fencing_pause && !fencing_pause.match(/^\d+(\.\d+)*$/))}
          info={messages.fencingPause}
          value={fencing_pause}
          onChange={this.handleInputChange(['fencing_pause'])}
        />
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
