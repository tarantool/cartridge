// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import SchemaEditor from 'src/components/SchemaEditor';
import { isValueChanged } from 'src/store/selectors/schema';
import { type State } from 'src/store/rootReducer';
import {
  getSchema,
  applySchema,
  setSchema,
  validateSchema
} from 'src/store/actions/schema.actions';
import { Alert, IconRefresh, Button, ControlsPanel } from '@tarantool.io/ui-kit';

const styles = {
  area: css`
    display: flex;
    flex-direction: column;
    height: calc(100% - 69px - 32px);
    padding: 16px;
    margin: 16px;
    border-radius: 4px;
    box-sizing: border-box;
    background-color: #ffffff;
  `,
  cardMargin: css`
    padding: 24px 16px;
    min-width: 1000px;
  `,
  title: css`
    margin-left: 16px;
  `,
  panel: css`
    display: flex;
    justify-content: flex-end;
    padding-bottom: 16px;
    margin-bottom: 16px;
    border-bottom: 1px solid #E8E8E8;
  `,
  editor: css`
    flex-grow: 1;
  `,
  errorPanel: css`
    margin-bottom: 0;
  `
};

type SchemaProps = {
  className?: string,
  value: string,
  valueChanged: boolean,
  error: ?string,
  loading: boolean,
  uploading: boolean,
  getSchema: () => void,
  setSchema: (s: string) => void,
  resetSchema: () => void,
  applySchema: () => void,
  validateSchema: () => void,
};

class Schema extends React.Component<SchemaProps> {
  componentDidMount() {
    if (!this.props.value) {
      this.props.getSchema();
    }
  }

  render() {
    const {
      className,
      error,
      value,
      loading,
      uploading,
      applySchema,
      getSchema,
      setSchema,
      validateSchema
    } = this.props;

    return (
      <div className={cx(styles.area, className)}>
        <div className={styles.panel}>
          <ControlsPanel
            thin
            controls={[
              <Button
                text='Reload'
                intent='secondary'
                size='s'
                onClick={getSchema}
                icon={IconRefresh}
              />,
              <Button text='Validate' size='s' onClick={validateSchema} />,
              <Button
                onClick={applySchema}
                text='Apply'
                intent='primary'
                size='s'
                loading={uploading}
                disabled={loading}
              />
            ]}
          />
        </div>
        <SchemaEditor
          className={styles.editor}
          fileId='ddl'
          value={value}
          onChange={setSchema}
        />
        {error && (
          <Alert className={styles.errorPanel} type='error'>{error}</Alert>
        )}
      </div>
    );
  }
}

const mapStateToProps = (state: State) => {
  const {
    schema: {
      value,
      error,
      loading,
      uploading
    }
  } = state;

  return {
    value,
    valueChanged: isValueChanged(state),
    error,
    loading,
    uploading
  };
};

const mapDispatchToProps = {
  getSchema,
  applySchema,
  setSchema,
  validateSchema
};

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(Schema);
