import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';
import ReactDragListView from 'react-drag-listview';
import { Col, Form, Row, Table } from "antd";
import Modal from 'src/components/Modal';
import Button from 'src/components/Button';
import Checkbox from '../Checkbox';
import Input from '../Input';
import Radio from "../Radio";

const formItemLayout = {
  labelCol: {
    span: 5
  },
  wrapperCol: {
    span: 19
  }
};

const normalizeProp = (prop, dataSource) => typeof prop === 'function' ? prop(dataSource) : prop;

const prepareFields = (shouldCreateItem, fields, formData) => fields
  .map(field => {
    const { customProps = {}, ...other } = field;
    return {
      ...other,
      ...(shouldCreateItem ? customProps.create : customProps.edit),
    };
  })
  .map(field => {
    return {
      ...field,
      hidden: normalizeProp(field.hidden, formData),
      options: normalizeProp(field.options, formData),
      disabled: normalizeProp(field.disabled, formData),
      title: normalizeProp(field.title, formData),
      helpText: normalizeProp(field.helpText, formData),
    };
  })
  .filter(field => ! field.hidden);

class CommonItemEditModal extends React.PureComponent {
  state = {
    formData: null,
    controlled: false,
  };

  constructor(props) {
    super(props);

    this.shouldCreateItem = props.shouldCreateItem;
  }

  static getDerivedStateFromProps(props, state) {
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
    const { title, isLoading, itemNotFound } = this.props;

    const preparedTitle = typeof title === 'string'
      ? title
      : this.shouldCreateItem ? title[0] : title[1];

    return (
      <Modal
        title={preparedTitle}
        visible
        width={691}
        onCancel={this.handleCancelClick}
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
            : this.renderForm()}
      </Modal>
    );
  }

  renderForm = () => {
    const { hideLabels, isSaving, submitStatusMessage } = this.props;
    const preparedFields = this.getFields();
    const submitDisabled = ! this.isFormReadyToSubmit();

    return (
      <Form onSubmit={this.handleSubmitClick}>
        <fieldset disabled={isSaving}>
          {preparedFields.map(field => (
            <Form.Item
              key={field.key}
              label={!hideLabels && field.title}
              labelAlign="left"
              validateStatus={!!field.invalidFeedback && !!field.invalid && field.invalid(this.state.formData) && 'error'}
              help={field.invalidFeedback || field.helpText}
              {...!hideLabels && formItemLayout}
            >
              {this.renderField(field)}
            </Form.Item>
          ))}

          <div>
            <Button
              type="primary"
              disabled={submitDisabled}
              onClick={this.handleSubmitClick}
            >
              Submit
            </Button>
            {submitStatusMessage
              ? (
                <div>
                  {submitStatusMessage}
                </div>
              )
              : null}
          </div>
        </fieldset>
      </Form>
    );
  };

  isFormReadyToSubmit = () => {
    const { isFormReadyToSubmit } = this.props;
    if (isFormReadyToSubmit) {
      const { formData } = this.state;
      return isFormReadyToSubmit(formData);
    }
    return true;
  };

  renderField = field => {
    switch (field.type) {
      case 'checkboxGroup':
        return this.renderCheckboxGroupField(field);

      case 'optionGroup':
        return this.renderOptionGroupField(field);

      case 'draggableList':
        return this.renderDraggableList(field);

      default:
        return this.renderInputField(field);
    }
  };

  renderDraggableList = field => {
    const dragProps = {
      onDragEnd: (fromIndex, toIndex) => {
        const data = [...this.state.formData.servers];
        const item = data.splice(fromIndex, 1)[0];
        data.splice(toIndex, 0, item);
        this.setState({ formData: {
          ...this.state.formData, servers: data,
        }});
      },
      handleSelector: "a"
    };

    return (
      <ReactDragListView {...dragProps}>
        <Table
          columns={field.tableColumns}
          pagination={false}
          dataSource={this.state.formData.servers}
          {...field.tableProps}
        />
      </ReactDragListView>
    )
  };


  renderInputField = field => {
    const { formData } = this.state;
    const value = formData[field.key] == null ? '' : String(formData[field.key]);

    return (
      <Input
        name={field.key}
        value={value}
        placeholder={field.placeholder}
        disabled={field.disabled}
        onChange={this.handleInputFieldChange}
      />
    );
  };

  renderCheckboxGroupField = field => {
    const values = this.state.formData[field.key] || [];

    return (
      <Row>
        {field.options.map(option => (
          <Col span={12} key={option.key}>
            <Checkbox
              name={field.key}
              value={option.key}
              checked={values.includes(option.key)}
              disabled={field.disabled}
              onChange={this.handleCheckboxGroupChange}
            >
              {option.label}
            </Checkbox>
          </Col>
        ))}
      </Row>
    );
  };

  renderOptionGroupField = field => {
    const value = this.state.formData[field.key];

    return field.options.map(option => (
      <Row key={option.key}>
        <Radio
          name={field.key}
          value={option.key}
          checked={value === option.key}
          disabled={field.disabled}
          onChange={this.handleOptionGroupChange}
        >
          {option.label}
        </Radio>
      </Row>
    ));
  };

  handleInputFieldChange = event => {
    const { formData } = this.state;
    const { target } = event;

    this.setState({ formData: { ...formData, [target.name]: target.value } });
  };

  handleCheckboxGroupChange = event => {
    const { formData } = this.state;
    const { target } = event;

    const values = formData[target.name];
    const newValues = target.checked
      ? [...values, target.value]
      : values.filter(option => option !== target.value);

    this.setState({ formData: { ...formData, [target.name]: newValues } });
  };

  handleOptionGroupChange = event => {
    const { formData } = this.state;
    const { target } = event;

    this.setState({ formData: { ...formData, [target.name]: target.value } });
  };

  handleSubmitClick = event => {
    event.preventDefault();
    const { onSubmit } = this.props;
    const { formData } = this.state;
    onSubmit(formData);
  };

  handleCancelClick = () => {
    const { onRequestClose } = this.props;
    const { formData } = this.state;
    onRequestClose(formData);
  };

  getFields = () => {
    const { fields } = this.props;
    const { formData } = this.state;
    return this.prepareFields(this.shouldCreateItem, fields, formData);
  };

  prepareFields = defaultMemoize(prepareFields);
}

CommonItemEditModal.propTypes = {
  title: PropTypes.oneOfType([
    PropTypes.string,
    PropTypes.arrayOf(PropTypes.string),
  ]),
  isLoading: PropTypes.bool,
  isSaving: PropTypes.bool,
  itemNotFound: PropTypes.bool,
  shouldCreateItem: PropTypes.bool,
  fields: PropTypes.arrayOf(PropTypes.shape({
    key: PropTypes.string.isRequired,
    hidden: PropTypes.oneOfType([
      PropTypes.bool,
      PropTypes.func,
    ]),
    type: PropTypes.oneOf(['input', 'checkboxGroup', 'optionGroup']),
    options: PropTypes.oneOfType([
      PropTypes.arrayOf(PropTypes.shape({
        key: PropTypes.string.isRequired,
        label: PropTypes.node,
      })),
      PropTypes.func,
    ]),
    disabled: PropTypes.oneOfType([
      PropTypes.bool,
      PropTypes.func,
    ]),
    title: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.func,
    ]),
    invalid: PropTypes.func,
    invalidFeedback: PropTypes.string,
    helpText: PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.func,
    ]),
    customProps: PropTypes.shape({
      create: PropTypes.object,
      edit: PropTypes.object,
    }),
  })),
  hideLabels: PropTypes.bool,
  dataSource: PropTypes.object,
  isFormReadyToSubmit: PropTypes.func,
  submitStatusMessage: PropTypes.string,
  onSubmit: PropTypes.func.isRequired,
  onRequestClose: PropTypes.func.isRequired,
  dispatch: PropTypes.func,
};

CommonItemEditModal.defaultProps = {
  title: ['Create', 'Edit'],
  isLoading: false,
  isSaving: false,
  itemNotFound: false,
  shouldCreateItem: false,
  hideLabels: false,
};

export default CommonItemEditModal;
