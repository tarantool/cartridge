// @flow
import React from 'react';
import { css, cx } from '@emotion/css';
import { Button, Dropdown, DropdownItem, IconMore } from '@tarantool.io/ui-kit';
import type { ButtonProps } from '@tarantool.io/ui-kit';

import { disableServer, failoverPromoteLeader, showExpelModal } from 'src/store/actions/clusterPage.actions';
import store from 'src/store/instance';

type ServerDropdownProps = {
  className?: string,
  activeMaster?: boolean,
  disabled: boolean,
  replicasetUUID: string,
  intent?: $ElementType<ButtonProps, 'intent'>,
  size?: $ElementType<ButtonProps, 'size'>,
  showFailoverPromote?: boolean,
  showServerDetails?: boolean,
  uri: string,
  history: History,
  uuid: string,
};

export class ServerDropdown extends React.PureComponent<ServerDropdownProps> {
  render() {
    const {
      activeMaster,
      className,
      disabled,
      intent,
      replicasetUUID,
      showFailoverPromote,
      showServerDetails,
      size,
      uri,
      history,
      uuid,
    } = this.props;

    return (
      <Dropdown
        items={[
          showServerDetails && (
            <DropdownItem key={0} onClick={() => history.push(`/cluster/dashboard/instance/${uuid}`)}>
              Server details
            </DropdownItem>
          ),
          showFailoverPromote && (
            <DropdownItem
              key={1}
              onClick={() => store.dispatch(failoverPromoteLeader(replicasetUUID, uuid, activeMaster))}
            >
              {activeMaster ? 'Force promote a leader' : 'Promote a leader'}
            </DropdownItem>
          ),
          <DropdownItem key={2} onClick={() => store.dispatch(disableServer(uuid, !disabled))}>
            {disabled ? 'Enable server' : 'Disable server'}
          </DropdownItem>,
          <DropdownItem
            key={3}
            className={css`
              color: rgba(245, 34, 45, 0.65);
            `}
            onClick={() => store.dispatch(showExpelModal(uri))}
          >
            Expel server
          </DropdownItem>,
        ].filter(Boolean)}
        className={cx(className, 'meta-test__ReplicasetServerListItem__dropdownBtn')}
        popoverClassName="meta-test__ReplicasetServerListItem__dropdown"
      >
        <Button icon={IconMore} size={size || 's'} intent={intent || 'plain'} />
      </Dropdown>
    );
  }
}
