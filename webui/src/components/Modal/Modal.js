import Modal from 'antd/lib/modal'
import * as React from 'react';
import {css} from "emotion";
import {Title} from '../styled'

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
  return <Modal {...{...defaultOption, ...props}} title={title} />;
};
