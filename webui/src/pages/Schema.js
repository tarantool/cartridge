// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import SchemaEditor from 'src/components/SchemaEditor';
import { isValueChanged } from 'src/store/selectors/schema';
import { type State } from 'src/store/rootReducer';
import {
  getSchema,
  applySchema,
  setSchema,
  validateSchema
} from 'src/store/actions/schema.actions';
import {
  Alert, IconRefresh, Button, ControlsPanel, PageLayout
} from '@tarantool.io/ui-kit';

const styles = {
  area: css`
    display: flex;
    flex-direction: column;
    flex-grow: 1;
    padding: 16px;
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
      <PageLayout
        heading='Schema'
        stretchVertical
        wide
      >
        <div className={styles.area}>
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
                <Button
                  text='Validate'
                  intent='secondary'
                  size='s'
                  onClick={validateSchema}
                />,
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
      </PageLayout>
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
