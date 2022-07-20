/* eslint-disable @typescript-eslint/ban-ts-comment */
import React from 'react';
import { cx } from '@emotion/css';
// prettier-ignore
// @ts-ignore
import { Button, DropdownDivider, DropdownItem, IconChevron, IconSearch, Input, withDropdown, } from '@tarantool.io/ui-kit';

import { styles } from './ReplicasetFilter.styles';

type DataFiltersType = Record<'prefix' | 'name', string>;

export type ReplicasetFilterType = {
  value: string;
  setValue: (value: string) => void;
  filters: DataFiltersType[];
  className: string;
  placeholder?: string;
};

const DropdownButton = withDropdown(Button);

const ReplicasetFilter = ({
  value,
  setValue,
  filters,
  className,
  placeholder = 'Filter by alias (leader and follower) ',
}: ReplicasetFilterType) => {
  return (
    <Input
      className={cx(styles.root, className)}
      placeholder={placeholder}
      value={value}
      onChange={(e) => setValue(e.target.value)}
      onClearClick={() => setValue('')}
      rightIcon={<IconSearch />}
      size="m"
      leftElement={presetsDropdown(setValue, filters || [])}
    />
  );
};

const presetsDropdown = (setValue: (s: string) => void, filters: DataFiltersType[]) => (
  <DropdownButton
    items={[
      ...filters?.map((filter) => getDropdownOption(filter?.prefix, setValue)(filter?.name, -1)),
      <DropdownDivider key="DropdownDivider" />,
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

export default ReplicasetFilter;
