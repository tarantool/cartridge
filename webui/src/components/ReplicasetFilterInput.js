// @flow
import * as React from 'react';
import { css, cx } from 'react-emotion';
import {
  IconSearch,
  Input,
  withDropdown,
  DropdownItem,
  DropdownDivider,
  Button,
  IconChevron
} from '@tarantool.io/ui-kit';
import type { Role } from 'src/generated/graphql-typing';

const DropdownButton = withDropdown(Button);

const styles = {
  clusterFilter: css`
    width: 385px;
    position: relative;
  `,
  chevron: css`
    fill: rgba(245, 34, 45, 0.65);
  `
};

type Props = {
  value: string,
  setValue: (s: string) => any,
  roles: ?Role[],
  className: string,
};

const ReplicasetFilterInput = ({
  value,
  setValue,
  roles,
  className
}: Props) => (
  <Input
    className={cx(styles.clusterFilter, className)}
    placeholder={'Filter by uri, uuid, role, alias or labels'}
    value={value}
    onChange={e => setValue(e.target.value)}
    onClearClick={() => setValue('')}
    rightIcon={<IconSearch />}
    leftElement={presetsDropdown(setValue, roles || [])}
  />
);


const presetsDropdown = (
  setValue: (s: string) => void, roles: Role[] = []
): React.Node => (
  <DropdownButton
    items={[
      ...['Healthy', 'Unhealthy'].map(getDropdownOption('status', setValue)),
      <DropdownDivider />,
      ...roles.map(role => getDropdownOption('role', setValue)(role.name))
    ]}
    intent='dark'
    iconRight={({ className }) => (
      <IconChevron
        direction='down'
        className={cx(styles.chevron, className)}
      />
    )}
    text='Filter'
    popoverClassName='meta-test__Filter__Dropdown'
  />
);

const getDropdownOption = (prefix, setValue) => option => (
  <DropdownItem
    onClick={() => setValue(
      `${prefix}:${option.indexOf(' ') !== -1 ? `"${option.toLowerCase()}"` : option.toLowerCase()}`
    )}
  >
    {option}
  </DropdownItem>
);

export default ReplicasetFilterInput;
