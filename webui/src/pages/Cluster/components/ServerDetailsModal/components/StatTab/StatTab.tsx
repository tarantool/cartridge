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

  const { http_address, params } = useMemo(
    () =>
      Object.entries(section ?? {}).reduce(
        (acc, [name, value]: [string, unknown]) => {
          if (name === 'http_host' || name === 'http_port' || name === 'webui_prefix') {
            acc.http_address[name] = `${value}`;
            return acc;
          }

          acc.params.push({
            name,
            value,
            displayAs: FIELDS_DISPLAY_TYPES[name] ?? 'string',
          });

          return acc;
        },
        {
          http_address: {
            http_host: '',
            http_port: '',
            webui_prefix: '',
          },
          params: [] as { name: string; value: unknown; displayAs: DisplayAs }[],
        }
      ),
    [section]
  );

  const items = useMemo(() => {
    if (!http_address.http_host) {
      return params;
    }

    return [
      ...params,
      {
        name: 'http_address',
        value: `${http_address.http_host}:${http_address.http_port}${http_address.webui_prefix}/`,
        displayAs: 'string' as DisplayAs,
      },
    ];
  }, [params, http_address]);

  return (
    <div className={styles.wrap}>
      {items.map(({ name, value, displayAs }) => (
        <div key={name} className={styles.listItem}>
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
