import Modal from 'antd/lib/modal'
import * as React from 'react'
import {css} from 'emotion'
import {Title} from '../styled'
import Button from 'src/components/Button'

const styles = {
  modal: css`
    .ant-modal-content{
      border-radius: 8px;
    }
    .ant-modal-header{
      background: #ECECEC;
    }
    
  `,
};

const defaultOption = {
  wrapClassName: styles.modal,
};

export default (props) => {
  let title = props.title;
  if (typeof title === 'string')
    title = <Title>{title}</Title>;

  const {okText, okType, onOk, onCancel, cancelText, confirmLoading} = props;

  const footer = [
    <Button key="back" onClick={onCancel}>
      {cancelText || 'Cancel'}
    </Button>,
    <Button key="submit" type={okType || 'primary'} loading={confirmLoading} onClick={onOk}>
      {okText || 'Ok'}
    </Button>,
  ]

  return <Modal footer={footer} {...{...defaultOption, ...props}} title={title} />;
};
