/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useMemo } from 'react';
import { useStore } from 'effector-react';
// @ts-ignore
import { Alert, Button, LabeledInput, Modal, Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { ProbeServerFormProps, withProbeServerForm } from './ProbeServerModalForm.form';

import { styles } from './ProbeServerModalForm.styles';

const { $serverProbeModal } = cluster.serverProbe;

const ProbeServerModalForm = ({
  handleSubmit,
  handleChange,
  handleBlur,
  handleReset,
  values,
  errors,
}: ProbeServerFormProps) => {
  const { error, pending } = useStore($serverProbeModal);

  const footerControls = useMemo(
    () => [
      <Button
        loading={pending}
        key="Submit"
        className="meta-test__ProbeServerSubmitBtn"
        type="submit"
        intent="primary"
        text="Submit"
        size="l"
      />,
    ],
    [pending]
  );

  return (
    <form className="meta-test___ProbeServerModal" onSubmit={handleSubmit} onReset={handleReset} noValidate>
      <Text className={styles.text}>{"Probe a server if it wasn't discovered automatically by UDP broadcast."}</Text>
      <LabeledInput
        autoFocus
        label="Server URI to probe"
        name="uri"
        value={values.uri}
        onChange={handleChange}
        onBlur={handleBlur}
        disabled={pending}
        error={Boolean(errors.uri)}
        message={errors.uri}
        placeholder="Server URI, e.g. localhost:3301"
      />
      {error && (
        <Alert className="ProbeServerModal_error" type="error">
          <Text tag="span">{error}</Text>
        </Alert>
      )}
      <Modal.Footer controls={footerControls} />
    </form>
  );
};

export default withProbeServerForm(ProbeServerModalForm);
