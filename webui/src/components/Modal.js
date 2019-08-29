// @flow
// TODO: move to uikit

/*
TODO:
- close on ESC,
- fix closing on background click
*/

import * as React from 'react';
import { createRef } from 'react';
import * as ReactDOM from 'react-dom';
import { css, cx } from 'emotion';
import { IconClose } from 'src/components/Icon';
import PopupFooter from 'src/components/PopupFooter';
import Text from 'src/components/Text';
import Button from './Button'

const styles = {
  shim: ({ bg }) => css`
    position: fixed;
    z-index: 100; /* TODO: to constants */
    left: 0;
    right: 0;
    top: 0;
    bottom: 0;
    display: flex;
    padding: 40px 16px;
    overflow: auto;
    background-color: ${bg ? bg : 'rgba(0, 0, 0, 0.65)'};
    justify-content: center;
    align-items: center;
  `,
  baseModal: css`
    position: relative;
    width: 100%;
    max-width: 600px;
    border-radius: 4px;
    margin: auto;
    box-sizing: border-box;
    background-color: #ffffff;
    box-shadow: 0px 5px 20px rgba(0, 0, 0, 0.09);
  `,
  modal: css`
    padding: 16px;
    margin: 0 auto auto;
  `,
  wide: css`
    max-width: 1000px;
  `,
  title: css`
    padding-bottom: 16px;
    padding-right: 24px;
    border-bottom: 1px solid rgba(55, 52, 66, 0.08);
    margin-bottom: 16px;
    padding-left: 16px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  `,
  closeIcon: css`
    position: absolute;
    top: 16px;
    right: 16px;
  `,
  content: css`
  `
};

const isNodeOutsideElement = (node: HTMLElement, element: HTMLElement) => !(element.contains(node) || element === node);

interface BaseModalProps {
  visible?: boolean,
  children?: React.Node,
  className?: string,
  wide?: boolean,
  onClose?: (?MouseEvent) => void,
  bgColor?: string,
}

interface ModalProps extends BaseModalProps {
  footerContent?: React.Node,
  footerControls?: React.Node,
  title: string,
  // onAfterOpen?: () => void;
  loading?:? boolean,
  // footer?: React.Node
};

interface ConfirmProps extends ModalProps {
  onConfirm: Function,
  onCancel: Function,
  confirmText?: string,
}

export const ConfirmModal = (
  {
    onConfirm,
    onCancel,
    confirmText = 'Ok',
    ...props
  }: ConfirmProps
) =>
  <Modal
    onClose={onCancel}
    footerControls={
      <React.Fragment>
        <Button intent={'base'} onClick={onCancel} className={css`margin-right: 16px;`}>Cancel</Button>
        <Button intent={'primary'} onClick={onConfirm}>{confirmText}</Button>
      </React.Fragment>
    }
    {...props}
  />


export class BaseModal<T: BaseModalProps = BaseModalProps> extends React.Component<T> {
  modalRef = createRef<HTMLElement>();

  render() {
    const { visible } = this.props;

    if (typeof visible === 'boolean' && !visible)
      return null;

    const root = document.body;

    if (root) {
      return ReactDOM.createPortal(this.renderModal(), root);
    }

    return null
  }

  renderModal() {
    const {
      children,
      className,
      wide,
      bgColor
    } = this.props;

    return (
      <div className={styles.shim({ bg: bgColor })} onClick={this.handleOutsideClick}>
        <div
          className={cx(
            styles.baseModal,
            { [styles.wide]: wide },
            className
          )}
          ref={this.modalRef}
        >
          {children}
        </div>
      </div>
    );
  }

  handleOutsideClick = (event: MouseEvent) => {
    const modal = this.modalRef.current;

    if (!!modal && event.target instanceof HTMLElement && isNodeOutsideElement(event.target, modal)) {
      this.props.onClose && this.props.onClose(event);
    }
  };
}

export default class Modal extends BaseModal<ModalProps> {

  renderModal() {
    const {
      children,
      className,
      footerContent,
      footerControls,
      title,
      onClose,
      loading,
      wide
    } = this.props;

    return (
      <div className={styles.shim({})} onClick={this.handleOutsideClick}>
        <div
          className={cx(
            styles.baseModal,
            styles.modal,
            { [styles.wide]: wide },
            className
          )}
          ref={this.modalRef}
        >
          <Text className={styles.title} variant='h2'>{title}</Text>
          {onClose && <IconClose className={styles.closeIcon} onClick={onClose} />}
          <div className={styles.content}>
            {loading ? 'Loading' : children}
          </div>
          {(footerContent || footerControls) && (
            <PopupFooter controls={footerControls}>{footerContent}</PopupFooter>
          )}
        </div>
      </div>
    );
  }
}
