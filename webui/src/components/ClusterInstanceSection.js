import React from 'react';
import { connect } from 'react-redux';
import Scrollbar from 'src/components/Scrollbar';
import Text from 'src/components/Text';
import CollapsibleJSONRenderer from 'src/components/CollapsibleJSONRenderer';
import { css, cx } from 'emotion';

const styles = {
  listOuter: css`
    min-height: 100px;
    height: 70vh;
    max-height: 400px;
    margin-top: 24px;
    margin-bottom: 40px;
  `,
  listInner: css``,
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
  replication_info: 'json'
};

const renderers = {
  string: value => (
    <Text variant="basic" className={styles.value}>
      {value instanceof Array ? `[${value.join(', ')}]` : value}
    </Text>
  ),
  json: value => <CollapsibleJSONRenderer value={value} />
};

const ClusterInstanceSection = ({ descriptions = {}, params = [] }) => {
  return (
    <div className={styles.listOuter}>
      <Scrollbar>
        <div className={styles.listInner}>
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
        </div>
      </Scrollbar>
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
  const section = boxinfo[sectionName];

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

