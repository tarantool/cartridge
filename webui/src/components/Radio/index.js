import React from 'react';
import Radio from 'antd/lib/radio';
import { css, cx } from 'emotion';

const primaryColor = '#666666';
const focusColor = '#343434';

const style = css`
  &.ant-radio-wrapper:hover .ant-radio-inner,
  & .ant-radio:hover .ant-radio-inner {
    border-color: ${focusColor}
  }

  & .ant-radio-inner::after {
    background-color: ${primaryColor};
  }

  & .ant-radio-checked .ant-radio-inner,
  & .ant-radio-checked::after {
    border-color: ${primaryColor};
  }

  & .ant-radio-input:focus + .ant-radio-inner {
    border-color: ${primaryColor};
    box-shadow: 0 0 0 3px rgba(0,0,0, 0.08);
  }
`;

const WrappedRadio = ({ className, ...props }) => (
  <Radio className={cx(className, style)} {...props} />
);

WrappedRadio.Button = Radio.Button;
WrappedRadio.Group = Radio.Group;

export default WrappedRadio;
