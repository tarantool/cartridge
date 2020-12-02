import React from 'react';
import { connect } from 'react-redux';
import { Text, colors } from '@tarantool.io/ui-kit';
import CollapsibleJSONRenderer from './CollapsibleJSONRenderer';
import { css } from 'emotion';

const styles = {
  wrap: css`
    padding: 0;
  `,
  listItem: css`
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
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
  subColumnContent: css`
    width: 100%;
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
  boolean: value => (
    <div className={styles.rightCol}>
      <Text variant='basic'>{value.toString()}</Text>
    </div>
  ),
  string: value => (
    <div className={styles.rightCol}>
      <Text variant='basic'>
        {value instanceof Array ? `[${value.join(', ')}]` : value}
      </Text>
    </div>
  ),
  json: value => <CollapsibleJSONRenderer value={value} />
};

const ServerDetailsModalStatTab = ({ descriptions = {}, params = [] }) => {
  return (
    <div className={styles.wrap}>
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
          {renderers[displayAs](value, index)}
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
    params: Object.entries(section)
      .map(([name, value]) => {
        const param = { name, value };

        if (fieldsDisplayTypes[name]) {
          param.displayAs = fieldsDisplayTypes[name];
        }

        return param;
      })
  }
};

export default connect(mapStateToProps)(ServerDetailsModalStatTab);

