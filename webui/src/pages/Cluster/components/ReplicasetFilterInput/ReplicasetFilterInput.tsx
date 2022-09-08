/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { cx } from '@emotion/css';
// prettier-ignore
// @ts-ignore
import { Button, DropdownDivider, DropdownItem, IconChevron, IconSearch, Input, withDropdown } from '@tarantool.io/ui-kit';

import type { GetClusterRole } from 'src/models';

import { styles } from './ReplicasetFilterInput.styles';

const DropdownButton = withDropdown(Button);

export interface ReplicasetFilterInputProps {
  value: string;
  setValue: (value: string) => void;
  roles: GetClusterRole[];
  className: string;
}

const ReplicasetFilterInput = ({ value, setValue, roles, className }: ReplicasetFilterInputProps) => {
  const handleDropdownSelectChange = (selected: string): void => {
    const prefix = selected.replace(/^(is|status|role):.+$/, '$1');
    if (!prefix) {
      setValue(selected);
      return;
    }

    if (value.indexOf(`${prefix}:`) > -1) {
      setValue(value.replace(new RegExp(prefix + ':[^\\s]+'), selected).trim());
    } else {
      setValue(`${value.trim()} ${selected}`.trim());
    }
  };

  return (
    <Input
      className={cx(styles.root, className)}
      placeholder={'Filter by uri, uuid, role, alias or labels'}
      value={value}
      onChange={(e) => setValue(e.target.value)}
      onClearClick={() => setValue('')}
      rightIcon={<IconSearch />}
      size="m"
      leftElement={presetsDropdown(handleDropdownSelectChange, roles || [])}
    />
  );
};

const presetsDropdown = (setValue: (s: string) => void, roles: GetClusterRole[] = []) => (
  <DropdownButton
    items={[
      ...['Healthy', 'Unhealthy'].map(getDropdownOption('status', setValue)),
      <DropdownDivider key="DropdownDivider1" />,
      ...['Leader', 'Follower'].map(getDropdownOption('is', setValue)),
      <DropdownDivider key="DropdownDivider2" />,
      ...roles.map((role) => getDropdownOption('role', setValue)(role.name, -1)),
    ]}
    intent="dark"
    iconRight={({ className }) => <IconChevron direction="down" className={cx(styles.chevron, className)} />}
    text="Filter"
    popoverClassName="meta-test__Filter__Dropdown"
  />
);

const getDropdownOption = (prefix, setValue) => (option, index: number) =>
  (
    <DropdownItem
      key={`${option}~${index}`}
      onClick={() =>
        setValue(`${prefix}:` + (option.indexOf(' ') !== -1 ? `"${option.toLowerCase()}"` : option.toLowerCase()))
      }
    >
      {option}
    </DropdownItem>
  );

export default ReplicasetFilterInput;
