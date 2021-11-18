/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback, useMemo } from 'react';
import { cx } from '@emotion/css';
import { useStore } from 'effector-react';
import { useFormikContext } from 'formik';
// @ts-ignore
// prettier-ignore
import { Alert, Button, Checkbox, FormField, InputPassword, LabeledInput, Modal, Select, Spin, Tabbed, Text, TextArea } from '@tarantool.io/ui-kit';

import { FAILOVER_STATE_PROVIDERS } from 'src/constants';
import { cluster } from 'src/models';

import { FailoverFormFormikProps, FailoverFormValues, withFailoverForm } from './FailoverModalForm.form';
import { FailoverMode, toFailoverMode, toFailoverStateProvider } from './FailoverModalForm.types';

import { styles } from './FailoverModalForm.styles';

const { $failoverModal, failoverModalCloseEvent } = cluster.failover;

const FAILOVER_MODES_INFO: Record<FailoverMode, string> = {
  disabled: 'The leader is the first instance according to topology configuration. No automatic decisions are taken.',
  eventual:
    'The leader isn’t elected consistently. Every instance thinks the leader is the first healthy server in the replicaset. The instance health is determined according to the membership status (the SWIM protocol).',
  stateful:
    'Leader appointments are polled from the external state provider. Decisions are taken by one of the instances with the failover-coordinator role enabled.',
};

const INFOS = {
  failoverTimeout: 'Timeout in seconds to mark suspect members as dead and trigger failover',
  fencingEnabled: 'A leader will go read-only when both the state provider and one of replicas are unreachable',
  fencingTimeout: 'Time in seconds to actuate the fencing after the health check fails',
  fencingPause: 'The period in seconds of performing the health check',
  lockDelayInfo: 'Expiration time of a lock that the failover-coordinator role acquires',
};

const FAILOVER_TABS: [FailoverMode, FailoverMode, FailoverMode] = ['disabled', 'eventual', 'stateful'];

export type FailoverModalFormProps = FailoverFormFormikProps;

const FailoverModalForm = ({ handleSubmit }: FailoverModalFormProps) => {
  const { loading, pending, error } = useStore($failoverModal);

  const { setFieldValue, handleChange, values, errors } = useFormikContext<FailoverFormValues>();

  const handleTabChange = useCallback(
    (index: number) => setFieldValue('mode', toFailoverMode(FAILOVER_TABS[index])),
    [setFieldValue]
  );

  const handleClose = useCallback(() => failoverModalCloseEvent(), []);

  const handleStateProviderChange = useCallback(
    (state_provider: string) =>
      setFieldValue('state_provider', toFailoverStateProvider(state_provider) ? state_provider : 'tarantool'),
    [setFieldValue]
  );

  const footerControls = useMemo(
    () => [
      <Button key="Cancel" className="meta-test__CancelButton" onClick={handleClose} size="l">
        Cancel
      </Button>,
      <Button
        key="Apply"
        className="meta-test__SubmitButton"
        intent="primary"
        type="submit"
        size="l"
        disabled={loading}
        loading={pending}
      >
        Apply
      </Button>,
    ],
    [handleClose, loading, pending]
  );

  const tabs = useMemo(
    () => [
      {
        label: 'Disabled',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['disabled']}
          </Text>
        ),
      },
      {
        label: 'Eventual',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['eventual']}
          </Text>
        ),
      },
      {
        label: 'Stateful',
        content: (
          <Text variant="p" className={styles.failoverInfo}>
            {FAILOVER_MODES_INFO['stateful']}
          </Text>
        ),
      },
    ],
    []
  );

  return (
    <Modal
      visible
      className="meta-test__FailoverModal"
      title="Failover control"
      onClose={handleClose}
      onSubmit={handleSubmit}
      footerControls={footerControls}
    >
      <Spin enable={loading}>
        <FormField label="Failover mode">
          <Tabbed
            size="small"
            className="meta-test__failover-tabs"
            activeTab={FAILOVER_TABS.findIndex((tab) => tab === values.mode)}
            handleTabChange={handleTabChange}
            tabs={tabs}
          />
        </FormField>
        <LabeledInput
          name="failover_timeout"
          label="Failover timeout"
          className="meta-test__failoverTimeout"
          error={errors.failover_timeout}
          message={errors.failover_timeout}
          value={values.failover_timeout}
          onChange={handleChange}
          info={INFOS.failoverTimeout}
        />
        {values.mode === 'stateful' && (
          <>
            <FormField label="Fencing" info={INFOS.fencingEnabled}>
              <Checkbox
                name="fencing_enabled"
                className="meta-test__fencingEnableCheckbox"
                checked={values.fencing_enabled}
                onChange={handleChange}
              >
                Enabled
              </Checkbox>
            </FormField>
            <div className={styles.inputs}>
              <LabeledInput
                name="fencing_timeout"
                label="Fencing timeout"
                className={cx(styles.inputField, 'meta-test__fencingTimeout')}
                disabled={!values.fencing_enabled}
                error={errors.fencing_timeout}
                message={errors.fencing_timeout}
                info={INFOS.fencingTimeout}
                value={values.fencing_timeout}
                onChange={handleChange}
              />
              <LabeledInput
                name="fencing_pause"
                label="Fencing pause"
                className={cx(styles.inputField, 'meta-test__fencingPause')}
                disabled={!values.fencing_enabled}
                error={errors.fencing_pause}
                message={errors.fencing_pause}
                info={INFOS.fencingPause}
                value={values.fencing_pause}
                onChange={handleChange}
              />
            </div>
            <LabeledInput
              name="state_provider"
              label="State provider"
              className="meta-test__stateProviderChoice"
              inputClassName={styles.select}
              inputComponent={Select}
              dropdownClassName="meta-test__StateProvider__Dropdown"
              options={FAILOVER_STATE_PROVIDERS}
              value={values.state_provider}
              onChange={handleStateProviderChange}
            />
            {values.state_provider === 'tarantool' && (
              <div className={styles.inputs}>
                <LabeledInput
                  name="tarantool_params.uri"
                  className={styles.inputField}
                  label="URI"
                  inputClassName="meta-test__stateboardURI"
                  error={errors.tarantool_params?.uri}
                  message={errors.tarantool_params?.uri}
                  value={values.tarantool_params.uri}
                  onChange={handleChange}
                />
                <LabeledInput
                  name="tarantool_params.password"
                  className={styles.inputField}
                  label="Password"
                  inputComponent={InputPassword}
                  inputClassName="meta-test__stateboardPassword"
                  error={errors.tarantool_params?.password}
                  message={errors.tarantool_params?.password}
                  value={values.tarantool_params.password}
                  onChange={handleChange}
                />
              </div>
            )}
            {values.state_provider === 'etcd2' && (
              <>
                <LabeledInput
                  name="etcd2_params.endpoints"
                  label="Endpoints"
                  className="meta-test__etcd2Endpoints"
                  inputComponent={TextArea}
                  error={errors.etcd2_params?.endpoints}
                  message={errors.etcd2_params?.endpoints}
                  value={values.etcd2_params.endpoints}
                  rows={2}
                  onChange={handleChange}
                />
                <div className={styles.inputs}>
                  <LabeledInput
                    name="etcd2_params.lock_delay"
                    className={styles.inputField}
                    label="Lock delay"
                    info={INFOS.lockDelayInfo}
                    error={errors.etcd2_params?.lock_delay}
                    message={errors.etcd2_params?.lock_delay}
                    inputClassName="meta-test__etcd2LockDelay"
                    value={values.etcd2_params.lock_delay}
                    onChange={handleChange}
                  />
                  <LabeledInput
                    name="etcd2_params.prefix"
                    className={styles.inputField}
                    label="Prefix"
                    inputClassName="meta-test__etcd2Prefix"
                    error={errors.etcd2_params?.prefix}
                    message={errors.etcd2_params?.prefix}
                    value={values.etcd2_params.prefix}
                    onChange={handleChange}
                  />
                  <LabeledInput
                    name="etcd2_params.username"
                    className={styles.inputField}
                    label="Username"
                    inputClassName="meta-test__etcd2Username"
                    error={errors.etcd2_params?.username}
                    message={errors.etcd2_params?.username}
                    value={values.etcd2_params.username}
                    onChange={handleChange}
                  />
                  <LabeledInput
                    name="etcd2_params.password"
                    className={styles.inputField}
                    label="Password"
                    inputClassName="meta-test__etcd2Password"
                    inputComponent={InputPassword}
                    error={errors.etcd2_params?.password}
                    message={errors.etcd2_params?.password}
                    value={values.etcd2_params.password}
                    onChange={handleChange}
                  />
                </div>
              </>
            )}
          </>
        )}
        {error && (
          <Alert type="error" className="meta-test__inlineError">
            <Text variant="basic">{error}</Text>
          </Alert>
        )}
      </Spin>
    </Modal>
  );
};

export default withFailoverForm(FailoverModalForm);
