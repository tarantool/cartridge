// @flow
import React from 'react';
import { css, cx } from 'react-emotion';
import { Formik } from 'formik';

import SelectedServersList from 'src/components/SelectedServersList';
import Text from 'src/components/Text';
import Scrollbar from 'src/components/Scrollbar';
import RadioButton from 'src/components/RadioButton';
import Button from 'src/components/Button';
import PopupBody from 'src/components/PopupBody';
import PopupFooter from 'src/components/PopupFooter';
import ReplicasetRoles from 'src/components/ReplicasetRoles';
import FormField from 'src/components/FormField';
import InputText from 'src/components/InputText';
import { IconSearch } from 'src/components/Icon';
import type {
  Server,
  Replicaset
} from 'src/generated/graphql-typing';

const styles = {
  form: css`
    display: flex;
    flex-wrap: wrap;
  `,
  input: css`
    margin-bottom: 4px;
  `,
  aliasInput: css`
    width: 50%;
  `,
  weightInput: css`
    width: 97px;
  `,
  errorMessage: css`
    display: block;
    height: 20px;
    color: #F5222D;
  `,
  filter: css`
    width: 305px;
  `,
  popupBody: css`
    min-height: 100px;
    height: 80vh;
    max-height: 480px;
  `,
  splash: css`
    flex-basis: 100%;
    max-width: 100%;
  `,
  wideField: css`
    flex-basis: 100%;
    margin-left: 16px;
    margin-right: 16px;
  `,
  radioWrap: css`
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    padding-bottom: 8px;
    border-bottom: solid 1px lightgray;
    margin-bottom: 8px;

    &:last-child {
      padding-bottom: 0;
      border-bottom: 0;
    }
  `,
  radio: css`
    flex-basis: calc(100% - 24px - 150px);
    max-width: calc(100% - 24px - 150px);
  `,
  replicasetServersCount: css`
    flex-basis: 150px;
    text-align: right;
  `,
  roles: css`
    flex-basis: 100%;
    margin-top: 8px;
  `
}

const validateForm = ({
  replicasetUuid
}) => {
  const errors = {};

  if (!replicasetUuid) {
    errors.replicasetUuid = 'Replicaset is required';
  }

  return errors;
};

type JoinReplicasetFormData = {
  uri: string,
  replicasetUuid: string,
};

type JoinReplicasetFormProps = {
  filter: string,
  filteredReplicasetList?: Replicaset[],
  onCancel: () => void,
  onSubmit: (d: JoinReplicasetFormData) => void,
  replicasetList?: Replicaset[],
  setFilter: (s: string) => void,
  selectedServers?: Server[]
};

class JoinReplicasetForm extends React.Component<JoinReplicasetFormProps> {
  componentWillUnmount () {
    this.props.setFilter('');
  };

  render() {
    const {
      filter,
      filteredReplicasetList,
      onCancel,
      onSubmit,
      replicasetList,
      selectedServers
    } = this.props;

    return (
      <Formik
        initialValues={{
          replicasetUuid: ''
        }}
        validate={validateForm}
        onSubmit={(values, { setSubmitting }) => {
          onSubmit({
            ...values,
            uri: selectedServers[0].uri
          });
        }}
      >
        {({
          values,
          errors,
          touched,
          handleChange,
          handleBlur,
          handleSubmit,
          isSubmitting
        }) => {
          return (
            <form className={styles.form} onSubmit={handleSubmit}>
              <PopupBody className={styles.popupBody}>
                <Scrollbar>
                  <SelectedServersList className={styles.splash} serverList={selectedServers} />
                  <FormField
                    className={styles.wideField}
                    itemClassName={styles.radioWrap}
                    label='Choose replica set'
                    subTitle={(
                      <Text variant='h5' upperCase tag='span'>
                        <b>{replicasetList.length}</b> total
                        {filteredReplicasetList.length !== replicasetList.length && (
                          <>, <b>{filteredReplicasetList.length}</b> filtered</>
                        )}
                      </Text>
                    )}
                    topRightControls={(
                      <InputText
                        className={styles.filter}
                        placeholder='Filter by uri, uuid, role, alias or labels'
                        value={filter}
                        onChange={this.handleFilterChange}
                        onClearClick={this.handleFilterClear}
                        rightIcon={<IconSearch />}
                      />
                    )}
                  >
                    {filteredReplicasetList && filteredReplicasetList.map(({ alias, servers, uuid, roles }) => (
                      <React.Fragment>
                        <RadioButton
                          onChange={handleChange}
                          className={styles.radio}
                          name='replicasetUuid'
                          value={uuid}
                          key={uuid}
                          checked={uuid === values.replicasetUuid}
                        >
                          {alias || uuid}
                        </RadioButton>
                        <Text className={styles.replicasetServersCount} variant='h5' upperCase tag='span'>
                          <b>{servers.length}</b>
                          {` active server${servers.length > 1 ? 's' : ''}`}
                        </Text>
                        <ReplicasetRoles className={styles.roles} roles={roles} />
                      </React.Fragment>
                    ))}
                  </FormField>
                </Scrollbar>
              </PopupBody>
              <PopupFooter
                controls={([
                  <Button type='button' onClick={onCancel}>Cancel</Button>,
                  <Button intent='primary' type='submit' disabled={Object.keys(errors).length}>
                    Join replica set
                  </Button>
                ])}
              />
            </form>
          )
        }}
      </Formik>
    );
  }

  handleFilterChange = (e: InputEvent) => {
    this.props.setFilter(e.target.value);
  };

  handleFilterClear = () => this.props.setFilter('');
}

export default JoinReplicasetForm;
