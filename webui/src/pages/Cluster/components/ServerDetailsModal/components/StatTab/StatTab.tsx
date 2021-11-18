import React, { createElement, useMemo } from 'react';
import { useStore } from 'effector-react';
import { Text } from '@tarantool.io/ui-kit';

import { cluster } from 'src/models';

import { BooleanRender } from './renderers/BooleanRender';
import { JsonRender } from './renderers/JsonRender';
import { StringRender } from './renderers/StringRender';

import { styles } from './StatTab.styles';

type DisplayAs = 'json' | 'boolean' | 'string';

const RENDERERS = {
  boolean: BooleanRender,
  string: StringRender,
  json: JsonRender,
};

const FIELDS_DISPLAY_TYPES: Record<string, DisplayAs> = {
  replication_info: 'json',
  ro: 'boolean',
  replication_skip_conflict: 'boolean',
  routers: 'json',
} as const;

const { $serverDetails, selectors } = cluster.serverDetails;

export interface StatTabProps {
  sectionName: 'general' | 'cartridge' | 'replication' | 'storage' | 'network' | 'membership' | 'vshard_storage';
}

const StatTab = ({ sectionName }: StatTabProps) => {
  const serverDetails = useStore($serverDetails);

  const { descriptions, section } = useMemo(
    () => selectors.sectionAndDescriptionsBySectionName(serverDetails, sectionName),
    [serverDetails, sectionName]
  );

  const params = useMemo(
    () =>
      Object.entries(section ?? {}).map(
        ([name, value]: [string, unknown]): { name: string; value: unknown; displayAs: DisplayAs } => {
          return {
            name,
            value,
            displayAs: FIELDS_DISPLAY_TYPES[name] ?? 'string',
          };
        }
      ),
    [section]
  );

  return (
    <div className={styles.wrap}>
      {params.map(({ name, value, displayAs }, index) => (
        <div key={index} className={styles.listItem}>
          <div className={styles.leftCol}>
            <Text variant="basic">{name}</Text>
            {descriptions?.[name] ? (
              <Text variant="basic" className={styles.description}>
                {descriptions[name]}
              </Text>
            ) : null}
          </div>
          {createElement(RENDERERS[displayAs], { value })}
        </div>
      ))}
    </div>
  );
};

export default StatTab;
