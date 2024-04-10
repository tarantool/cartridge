/* eslint-disable @typescript-eslint/ban-ts-comment */
import React, { useCallback } from 'react';
import { css } from '@emotion/css';
import { useEvent, useStore } from 'effector-react';
// @ts-ignore
import { Button, IconFailed, IconSuccess, Text, UriLabel, withPopover } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { FailoverStateProvider } from './FailoverModalForm.types';

export const styles = {
  root: css`
    display: flex;
    flex-direction: column;
    flex-wrap: nowrap;
    gap: 4px;
  `,
  header: css`
    display: block;
    margin-bottom: 8px;
  `,
};

const PopoverRoot = withPopover(Button);
const { $stateProviderStatus, stateProviderStatusGetEvent, getStateProviderStatusFx } = cluster.failover;

export const FailoverModalFormStateProviderStatusAction = ({
  stateProvider,
}: {
  stateProvider: FailoverStateProvider;
}) => {
  const stateProviderStatusPending = useStore(getStateProviderStatusFx.pending);
  const stateProviderStatus = useStore($stateProviderStatus);
  const event = useEvent(stateProviderStatusGetEvent);
  const handleClick = useCallback(() => {
    event();
  }, [event]);

  return (
    <PopoverRoot
      size="xs"
      type="button"
      onClick={handleClick}
      loading={stateProviderStatusPending}
      disabled={stateProviderStatusPending}
      popoverContent={
        stateProviderStatusPending || !stateProviderStatus || stateProviderStatus.length === 0 ? undefined : (
          <div className={styles.root}>
            <Text className={styles.header}>
              {stateProvider === 'etcd2' ? 'etcd' : stateProvider} state provider status:
            </Text>
            {stateProviderStatus.map((value, index) => (
              <UriLabel
                key={index}
                uri={value.uri}
                title={value.status ? 'status: true' : 'status: false'}
                icon={value.status ? IconSuccess : IconFailed}
              />
            ))}
          </div>
        )
      }
    >
      status
    </PopoverRoot>
  );
};
