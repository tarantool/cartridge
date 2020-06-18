import React from 'react';
import { connect } from 'react-redux';
import { PopupBody, Text } from '@tarantool.io/ui-kit';
import CollapsibleJSONRenderer from 'src/components/CollapsibleJSONRenderer';
import { css } from 'emotion';

const styles = {
  listInner: css`
    padding: 24px 0;
  `,
  listItem: css`
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 16px;
    
    & + & {
      border-top: 1px solid #d9d9d9;
    }
    
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
  key: css`
    line-height: 18px;
  `,
  description: css`
    line-height: 16px;
    font-size: 11px;
    color: rgba(0, 0, 0, 0.65);
  `,
  value: css`
    line-height: 18px;
  `
};

const fieldsDisplayTypes = {
  replication_info: 'json',
  ro: 'boolean',
  replication_skip_conflict: 'boolean'
};

const renderers = {
  boolean: value => <Text variant="basic" className={styles.value}>{value.toString()}</Text>,
  string: value => (
    <Text variant="basic" className={styles.value}>
      {value instanceof Array ? `[${value.join(', ')}]` : value}
    </Text>
  ),
  json: value => <CollapsibleJSONRenderer value={value} />
};

const ClusterInstanceSection = ({ descriptions = {}, params = [] }) => {
  return (
    <PopupBody className={styles.listInner}>
      {params.map(({ name, value, displayAs = 'string' }, index) => (
        <div className={styles.listItem}>
          <div className={styles.leftCol}>
            <Text variant="basic" className={styles.key}>
              {name}
            </Text>
            {descriptions[name]
              ? (
                <Text variant="basic" className={styles.description}>
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
    </PopupBody>
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

