import React, { memo, useMemo } from 'react';
import { useStore } from 'effector-react';
import { Text } from '@tarantool.io/ui-kit';

import { app, cluster } from 'src/models';

import { styles } from './VshardRouterTab.styles';

const { compact } = app.utils;
const { $serverDetails, selectors } = cluster.serverDetails;

const VshardRouterTab = () => {
  const serverDetails = useStore($serverDetails);

  const { descriptions, section } = useMemo(() => {
    const values = selectors.sectionAndDescriptionsBySectionName(serverDetails, 'vshard_router');
    return {
      descriptions: values.descriptions,
      section: values.section && Array.isArray(values.section) ? compact(values.section) : [],
    };
  }, [serverDetails]);

  const result = useMemo(
    () =>
      Object.entries(section ?? []).map(([, item]) => {
        return {
          name: item.vshard_group,
          params: Object.entries(item)
            .filter(([name]) => name !== 'vshard_group')
            .map(([name, value]) => ({ name, value })),
        };
      }),
    [section]
  );

  if (result.length === 0) {
    return null;
  }

  return (
    <div className={styles.wrap}>
      {result.map(({ name, params }, index1) => (
        <div key={index1}>
          <Text className={styles.subtitle} variant="h5">
            vshard group: {name}
          </Text>
          <div>
            {params.map(({ name, value }, index2) => (
              <div key={index2} className={styles.listItem}>
                <div className={styles.leftCol}>
                  <Text variant="basic">{name}</Text>
                  {descriptions?.[name] ? (
                    <Text variant="basic" className={styles.description}>
                      {descriptions[name]}
                    </Text>
                  ) : null}
                </div>
                <div className={styles.rightCol}>
                  <Text variant="basic">{Array.isArray(value) ? `[${value.join(', ')}]` : value}</Text>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};

export default memo(VshardRouterTab);
