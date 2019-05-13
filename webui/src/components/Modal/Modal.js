import Modal from 'antd/lib/modal'
import * as React from 'react'
import {css} from 'emotion'
import {Title} from '../styled'
import ClusterButton from 'src/components/ClusterButton'

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
    <ClusterButton key="back" onClick={onCancel}>
      {cancelText || 'Cancel'}
    </ClusterButton>,
    <ClusterButton key="submit" type={okType || 'primary'} loading={confirmLoading} onClick={onOk}>
      {okText || 'Ok'}
    </ClusterButton>,
  ]

  return <Modal footer={footer} {...{...defaultOption, ...props}} title={title} />;
};
