// @flow
import React from 'react';
import { connect } from 'react-redux';
import { css } from 'emotion';
import { Alert, IconRefresh, Button } from '@tarantool.io/ui-kit';
import SchemaEditor from 'src/components/SchemaEditor';
import { isValueChanged } from 'src/store/selectors/schema';
import { type State } from 'src/store/rootReducer';
import {
  getSchema,
  applySchema,
  setSchema,
  validateSchema
} from 'src/store/actions/schema.actions';
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
        wide
        topRightControls={[
          <Button
            text='Reload'
            intent='base'
            size='l'
            onClick={getSchema}
            icon={IconRefresh}
          />,
          <Button
            text='Validate'
            intent='base'
            size='l'
            onClick={validateSchema}
          />,
          <Button
            onClick={applySchema}
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
