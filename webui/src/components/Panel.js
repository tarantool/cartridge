import * as React from 'react'
import styled, { css } from 'react-emotion'

const styles = {
  title: css`
    padding-bottom: 16px;
    border-bottom: 1px solid #e8e8e8;
  `,
  content: css`
    font-family: Open Sans;
    font-size: 14px;
    font-weight: normal;
    font-style: normal;
    font-stretch: normal;
    line-height: 1.57;
    letter-spacing: 0.28px;
    padding-top: 16px;
    color: #000000;
  `
};

export const Panel = styled.div`
  padding: 12px 16px;
  margin-bottom: 8px;
  border-radius: 2px;
  background-color: #ffffff;
  box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.11);
`

export const TitledPanel = ({ title, content, className }) =>
  <Panel className={className}>
    <div className={styles.title}>{title}</div>
    <div className={styles.content}>{content}</div>
  </Panel>

export default Panel
