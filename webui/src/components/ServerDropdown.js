// @flow
import * as React from 'react';
import { css, cx } from 'react-emotion';
import {
  Button,
  Dropdown,
  DropdownItem,
  IconMore,
  type ButtonProps
} from '@tarantool.io/ui-kit';
import store from 'src/store/instance';
import { failoverPromoteLeader, showExpelModal } from 'src/store/actions/clusterPage.actions';

type ServerDropdownProps = {
  className?: string,
  activeMaster?: boolean,
  replicasetUUID: string,
  intent?: $ElementType<ButtonProps, 'intent'>,
  size?: $ElementType<ButtonProps, 'size'>,
  showFailoverPromote?: boolean,
  showServerDetails?: boolean,
  uri: string,
  history: History,
  uuid: string
};

export class ServerDropdown extends React.PureComponent<ServerDropdownProps> {
  render() {
    const {
      activeMaster,
      className,
      intent,
      replicasetUUID,
      showFailoverPromote,
      showServerDetails,
      size,
      uri,
      history,
      uuid
    } = this.props;

    return (
      <Dropdown
        items={[
          showServerDetails
            ? (
              <DropdownItem onClick={() => history.push(`/cluster/dashboard/instance/${uuid}`)}>
                Server details
              </DropdownItem>
            )
            : null,
          showFailoverPromote
            ? (
              <DropdownItem
                onClick={() => store.dispatch(
                  failoverPromoteLeader(replicasetUUID, uuid, activeMaster)
                )}
              >
                {activeMaster ? 'Force promote a leader' : 'Promote a leader'}
              </DropdownItem>
            )
            : null,
          <DropdownItem
            className={css`color: rgba(245, 34, 45, 0.65);`}
            onClick={() => store.dispatch(showExpelModal(uri))}
          >
            Expel server
          </DropdownItem>
        ]}
        className={cx(className, 'meta-test__ReplicasetServerListItem__dropdownBtn')}
        popoverClassName='meta-test__ReplicasetServerListItem__dropdown'
      >
        <Button
          icon={IconMore}
          size={size || 's'}
          intent={intent || 'plain'}
        />
      </Dropdown>
    )
  }
}
