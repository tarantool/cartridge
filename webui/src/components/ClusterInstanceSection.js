import React from 'react';
import { connect } from 'react-redux';
import { Text, colors } from '@tarantool.io/ui-kit';
import CollapsibleJSONRenderer from 'src/components/CollapsibleJSONRenderer';
import { css } from 'emotion';

const styles = {
  listInner: css`
    padding: 0;
  `,
  listItem: css`
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 20px;

    &:nth-child(2n) {
      background-color: #fafafa; 
    }
  `,
  leftCol: css`
    display: flex;
    flex-direction: column;
    max-width: 50%;
  `,
  rightCol: css`
    max-width: 50%;
  `,
  description: css`
    color: ${colors.dark40};
  `
};

const fieldsDisplayTypes = {
  replication_info: 'json',
  ro: 'boolean',
  replication_skip_conflict: 'boolean'
};

const renderers = {
  boolean: value => <Text variant='basic'>{value.toString()}</Text>,
  string: value => (
    <Text variant='basic'>
      {value instanceof Array ? `[${value.join(', ')}]` : value}
    </Text>
  ),
  json: value => <CollapsibleJSONRenderer value={value} />
};

const ClusterInstanceSection = ({ descriptions = {}, params = [] }) => {
  return (
    <div className={styles.listInner}>
      {params.map(({ name, value, displayAs = 'string' }, index) => (
        <div className={styles.listItem}>
          <div className={styles.leftCol}>
            <Text variant='basic'>{name}</Text>
            {descriptions[name]
              ? (
                <Text variant='basic' className={styles.description}>
                  {descriptions[name]}
                </Text>
              )
              : null}
          </div>
          <div className={styles.rightCol}>
            {renderers[displayAs](value, index)}
          </div>
        </div>
      ))}
    </div>
  );
};

const mapStateToProps = (
  {
    clusterInstancePage: {
      boxinfo,
      descriptions
    }
  },
  { sectionName }
) => {
  const section = (boxinfo && boxinfo[sectionName]) || {};

  return {
    descriptions: descriptions[sectionName],
    params: Object.keys(section)
      .map(key => {
        const param = {
          name: key,
          value: section[key]
        };

        if (fieldsDisplayTypes[key]) {
          param.displayAs = fieldsDisplayTypes[key];
        }

        return param;
      })
  }
};

export default connect(mapStateToProps)(ClusterInstanceSection);

