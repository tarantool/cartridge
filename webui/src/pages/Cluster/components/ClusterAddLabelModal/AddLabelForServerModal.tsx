import React, { useCallback, useMemo, useState } from 'react';
import { css } from '@emotion/css';
import { useStore } from 'effector-react';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Button, Input, Modal, Tag } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

const { $serverLabels, addLabelEvent, removeLabelEvent, serverAddLabelModalCloseEvent, editServerEvent } =
  cluster.addLabels;

const styles = {
  wrap: css`
    display: flex;
  `,
  field: css`
    margin-left: 16px;
    margin-right: 30px;
  `,
  input: css`
    margin-bottom: 20px;
    position: relative;
  `,
  error: css`
    color: red;
    font-size: 12px;
    position: absolute;
    left: 0;
    text-align: left;
  `,
};

const AddLabelsForServerModal = () => {
  const [values, setValues] = useState('');
  const [error, setError] = useState(false);
  const { visible, labels } = useStore($serverLabels);

  const handelChange = useCallback(
    (event: React.ChangeEvent<HTMLInputElement>) => setValues(event.target.value),
    [setValues]
  );
  const handelTag = useCallback(
    (event: React.MouseEvent<HTMLDivElement>) =>
      event.currentTarget.textContent && removeLabelEvent(event.currentTarget.textContent),
    []
  );
  const writeLabel = useCallback(() => {
    if (values) {
      addLabelEvent({ name: values, value: values });
      setValues('');
    } else {
      setError(true);
    }
  }, [values]);

  const handelClose = useCallback(() => serverAddLabelModalCloseEvent(), []);

  const handelChangeLabels = useCallback(() => {
    editServerEvent();
    serverAddLabelModalCloseEvent();
  }, []);

  const handleFocus = useCallback(() => {
    if (error) {
      setError(false);
    }
  }, [error]);

  const tagLabels = useMemo(() => {
    return labels?.map((label) => <Tag onClick={handelTag} key={label?.value} text={label?.value} />);
  }, [handelTag, labels]);

  return (
    <Modal
      visible={visible}
      className="LabelsAddModal"
      footerControls={[
        <Button key="Apply" intent="primary" size="l" text="Change labels" onClick={handelChangeLabels} />,
      ]}
      onClose={handelClose}
      title="Added labels for server"
    >
      <div className={styles.wrap}>
        <div className={styles.field}>
          <div className={styles.input}>
            <Input onFocus={handleFocus} name="alias" onChange={handelChange} value={values} />
            {error && <span className={styles.error}>The field cannot be empty</span>}
          </div>
          <Button key="Add" intent="primary" size="s" text="Add Label" onClick={writeLabel} />
        </div>
        <div>{tagLabels}</div>
      </div>
    </Modal>
  );
};

export default AddLabelsForServerModal;
