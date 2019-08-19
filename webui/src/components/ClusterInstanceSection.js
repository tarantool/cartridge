import React from 'react';
import { connect } from 'react-redux';
import Scrollbar from 'src/components/Scrollbar';
import Text from 'src/components/Text';
import { css, cx } from 'emotion';

const styles = {
  listOuter: css`
    min-height: 100px;
    height: 70vh;
    max-height: 400px;
    margin-top: 20px;
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
  `,
  collapse: css`
    position: relative;
    margin-top: 6px;
    margin-bottom: 6px;
    
    input {
      display: none;
    }
    
    input:checked + * {
      padding-right: 0;
      white-space: pre;
      text-overflow: initial;
    }
  `,
  structuredValue: css`
    overflow: hidden;
    display: inline-block;
    width: 100%;
    padding-right: 70px;
    line-height: 18px;
    white-space: nowrap;
    text-overflow: ellipsis;
  `,
  collapseLabel: css`
    position: absolute;
    right: 0;
    line-height: 18px;
    
    & > label {
      cursor: pointer;
      color: #f5222d;
    }
  `,
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
  json: (value, index) => {
    const id = `cluster-instance-sectino-${index}`;

    return (
      <div className={styles.collapse}>
        <Text variant="basic" className={styles.collapseLabel}>
          <label htmlFor={id}>collapse</label>
        </Text>
        <input id={id} type="checkbox" />
        <Text variant="basic" className={styles.structuredValue}>
          {JSON.stringify(value, null, 2)}
        </Text>
      </div>
    );
  }
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

