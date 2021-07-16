// @flow
import React, { useEffect } from 'react';
import { css } from '@emotion/css';
import { useStore } from 'effector-react';
import { Alert, IconRefresh, Button } from '@tarantool.io/ui-kit';
import SchemaEditor from 'src/components/SchemaEditor';
import {
  $form,
  applyClick,
  applySchemaFx,
  checkSchemaFx,
  getSchemaFx,
  inputChange,
  validateClick,
  schemaPageMount
} from 'src/store/effector/schema';
import { PageLayout } from 'src/components/PageLayout';

const styles = {
  area: css`
    display: flex;
    flex-direction: column;
    flex-grow: 1;
    padding: 16px;
    border-radius: 4px;
    box-sizing: border-box;
    overflow: hidden;
    background-color: #ffffff;
  `,
  cardMargin: css`
    padding: 24px 16px;
    min-width: 1000px;
  `,
  title: css`
    margin-left: 16px;
  `,
  editor: css`
    flex-grow: 1;
  `,
  errorPanel: css`
    margin-bottom: 0;
  `
};

applySchemaFx.done.watch(() => window.tarantool_enterprise_core.notify({
  title: 'Success',
  message: 'Schema successfully applied',
  type: 'success',
  timeout: 10000
}));

checkSchemaFx.done.watch(() => window.tarantool_enterprise_core.notify({
  title: 'Schema validation',
  message: 'Schema is valid',
  type: 'success',
  timeout: 10000
}));

const Schema = () => {
  useEffect(() => {
    schemaPageMount();
  }, []);

  const {
    checking,
    loading,
    uploading,
    value,
    error
  } = useStore($form);

  return (
    <PageLayout
      heading='Schema'
      wide
      topRightControls={[
        <Button
          text='Reload'
          intent='base'
          size='l'
          onClick={getSchemaFx}
          icon={IconRefresh}
          loading={loading}
        />,
        <Button
          text='Validate'
          intent='base'
          size='l'
          onClick={validateClick}
          loading={checking}
        />,
        <Button
          onClick={applyClick}
          text='Apply'
          intent='primary'
          size='l'
          loading={uploading}
          disabled={loading}
        />
      ]}
    >
      <div className={styles.area}>
        <SchemaEditor
          className={styles.editor}
          fileId='ddl'
          value={value}
          onChange={inputChange}
        />
        {error && (
          <Alert className={styles.errorPanel} type='error'>{error}</Alert>
        )}
      </div>
    </PageLayout>
  );
};

export default Schema;
