import React from 'react';
import Checkbox from 'antd/lib/checkbox';
import { css, cx } from 'emotion';

const primaryColor = '#666666';
const focusColor = '#343434';
const disabledBgColor = '#f5f5f5';

const style = css`
  &.ant-checkbox-wrapper:hover .ant-checkbox-inner,
  & .ant-checkbox:hover .ant-checkbox-inner,
  & .ant-checkbox-input:focus + .ant-checkbox-inner {
    border-color: ${focusColor}
  }

  & .ant-checkbox-checked .ant-checkbox-inner {
    background-color: ${primaryColor};
    border-color: ${primaryColor};
  }

  & .ant-checkbox-checked::after {
    border-color: ${primaryColor};
  }

  & .ant-checkbox-disabled .ant-checkbox-inner {
    background-color: ${disabledBgColor};
  }
`;

const WrappedCheckbox = ({ className, ...props }) => (
  <Checkbox className={cx(className, style)} {...props} />
);

WrappedCheckbox.Group = Checkbox.Group;

export default WrappedCheckbox;
