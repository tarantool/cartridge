import React from 'react';
import Input from 'antd/lib/input';
import { css, cx } from 'emotion';

const hoverColor = '#999999';

const style = css`
  &.ant-input-affix-wrapper:hover .ant-input:not(.ant-input-disabled) {
    border-color: ${hoverColor};
  }

  & .ant-input:focus {
    border-color: ${hoverColor};
    box-shadow: 0 0 0 2px rgba(144, 144, 144, 0.2);
  }
`;

const WrappedInput = ({ className, ...props }) => (
  <Input className={cx(className, style)} {...props} />
);

WrappedInput.Group = Input.Group;
WrappedInput.Password = Input.Password;
WrappedInput.Search = Input.Search;
WrappedInput.TextArea = Input.TextArea;

export default WrappedInput;
