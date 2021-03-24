// @flow
import React from 'react';
import { css } from 'emotion'
import { useStore } from 'effector-react';
import { connect } from 'react-redux';
import {
  Alert,
  Button,
  Checkbox,
  Modal,
  Text,
  colors,
  FormField
} from '@tarantool.io/ui-kit';
import type { Server } from 'src/generated/graphql-typing';
import type { State } from 'src/store/rootReducer';
import {
  $forceApplyModal,
  forceApplyConfApplyClick,
  forceApplyInstanceCheck,
  forceApplyReasonCheck,
  forceApplyReasonUncheck,
  detailsClose
} from 'src/store/effector/clusterSuggestions';

const styles = {
  msg: css`
    margin-bottom: 20px;
    white-space: pre-line;
  `,
  list: css`
    list-style: none;
    padding-left: 0;
    color: ${colors.dark65};
  `,
  listItem: css`
    margin-bottom: 11px;

    &:last-child {
      margin-bottom: 0;
    }
  `
};

const fieldLabels = {
  operation_error: 'Operation error',
  config_error: 'Configuration error'
}

const msg = 'Some instances are misconfigured. \
You can heal it by reapplying configuration forcefully.';

type Props = {
  serverList?: Server[]
}

export const ForceApplySuggestionModal = ({ serverList }: Props) => {
  const {
    checked,
    visible,
    error,
    pending,
    suggestions
  } = useStore($forceApplyModal);

  if (!visible)
    return null;

  const serversLabels = (serverList || []).reduce(
    (acc, { uuid, alias, uri }) => {
      acc[uuid] = `${uri}${alias ? ` (${alias})` : ''}`;
      return acc;
    },
    {}
  );

  return (
    <Modal
      className='meta-test__ForceApplySuggestionModal'
      footerControls={[
        <Button
          intent='primary'
          size='l'
          text='Force apply'
          onClick={forceApplyConfApplyClick}
          loading={pending}
        />
      ]}
      onClose={detailsClose}
      title='Force apply configuration'
    >
      <Text className={styles.msg} tag='p'>{msg}</Text>
      {suggestions.map(([reason, uuids]) => {
        const deselectAll = uuids.map(uuid => checked[uuid]).every(c => c);

        return uuids.length
          ? (
            <FormField
              className='meta-test__errorField'
              label={fieldLabels[reason]}
              key={reason}
              subTitle={(
                <Button
                  intent='plain'
                  onClick={() => deselectAll
                    ? forceApplyReasonUncheck(reason)
                    : forceApplyReasonCheck(reason)}
                  size='xs'
                  text={deselectAll ? 'Deselect all' : 'Select all'}
                />
              )}
            >
              {uuids.map(uuid => (
                <Checkbox
                  checked={checked[uuid]}
                  onChange={() => forceApplyInstanceCheck(uuid)}
                >
                  {serversLabels[uuid]}
                </Checkbox>
              ))}
            </FormField>
          )
          : null
      })}
      {error && (
        <Alert type='error'>
          <Text variant='basic'>{error}</Text>
        </Alert>
      )}
    </Modal>
  );
};

const mapStateToProps = ({ clusterPage: { serverList } }: State) => {
  return { serverList };
};

export default connect(mapStateToProps)(ForceApplySuggestionModal);
