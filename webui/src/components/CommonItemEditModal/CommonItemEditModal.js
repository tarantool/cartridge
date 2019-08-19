// @flow
import * as React from 'react';
import { css } from 'emotion';
import CommonItemEditForm from 'src/components/CommonItemEditForm';
import Modal from 'src/components/Modal';

type FormData = { [key: string]: string | string[] };

type CommonItemEditModalFieldOptions = Array<{
  key: string,
  label: string | React.Component<any>,
  disabled?: boolean
}>;

export type CommonItemEditModalField = {
  key: string,
  hidden?: boolean | (d: FormData) => boolean,
  type?: 'input' | 'checkboxGroup' | 'optionGroup' | 'draggableList',
  options?: CommonItemEditModalFieldOptions | (d: FormData) => CommonItemEditModalFieldOptions,
  dataSource?: string,
  disabled?: boolean | (d: FormData) => boolean,
  tableColumns?: {
    dataIndex?: string,
    title?: string,
    key?: string,
    render?: () => React$Element<>,
    width?: number | string
  },
  tableProps?: {
    showHeader?: boolean,
    className?: string,
    rowKey?: string
  },
  title?: string | (d: FormData) => string,
  invalid?: () => boolean,
  invalidFeedback?: string,
  helpText?: string | (d: FormData) => string,
  placeholder?: string,
  stateModifier: (prevState: FormData, nextState: FormData, fromIndex?: number, toIndex?: number) => FormData,
  customProps: {
    create: Object,
    edit: Object
  }
};

type CommonItemEditModalProps = {
  errorMessage: ?string,
  title: ?(string | string[]),
  isLoading: ?boolean,
  isSaving: ?boolean,
  itemNotFound: ?boolean,
  shouldCreateItem: ?boolean,
  fields: CommonItemEditModalField[],
  hideLabels: ?boolean,
  dataSource: ?FormData,
  isFormReadyToSubmit: ?(d: ?FormData) => boolean,
  submitStatusMessage: ?string,
  onSubmit: (d: FormData) => void,
  onRequestClose: (d: FormData) => void
};

type CommonItemEditModalState = {
  formData: ?FormData,
  controlled: boolean
}
class CommonItemEditModal extends React.PureComponent<CommonItemEditModalProps, CommonItemEditModalState> {
  shouldCreateItem: boolean;

  static defaultProps = {
    title: ['Create', 'Edit'],
    isLoading: false,
    isSaving: false,
    itemNotFound: false,
    shouldCreateItem: false,
    hideLabels: false
  };

  state = {
    formData: null,
    controlled: false
  };

  constructor(props: CommonItemEditModalProps) {
    super(props);

    this.shouldCreateItem = !!props.shouldCreateItem;
  }

  static getDerivedStateFromProps(props: CommonItemEditModalProps, state: CommonItemEditModalState) {
    const derivedState = {};

    if ( ! state.controlled) {
      if ( ! props.isLoading) {
        derivedState.controlled = true;
        derivedState.formData = props.dataSource || {};
      }
    }

    return derivedState;
  }

  render() {
    const { title, isLoading, itemNotFound, onRequestClose } = this.props;

    const preparedTitle = title instanceof Array
      ? this.shouldCreateItem ? title[0] : title[1]
      : title;

    return (
      <Modal
        title={preparedTitle}
        visible
        wide
        onClose={onRequestClose}
        footer={null}
      >
        {isLoading
          ? (
            <div>
              Loading...
            </div>
          )
          : itemNotFound
            ? (
              <div>
                Item not found
              </div>
            )
            : (
              <CommonItemEditForm {...this.props} />
            )}
      </Modal>
    );
  }
}

export default CommonItemEditModal;
