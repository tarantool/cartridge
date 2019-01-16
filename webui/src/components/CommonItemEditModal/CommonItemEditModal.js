import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import Modal from 'src/components/Modal';
import cn from 'src/misc/cn';

const getOptionFormName = parts => `${parts[0]}[${parts[1]}]`;

const parseOptionFormName = optionFormName => {
  const match = optionFormName.match(/^([^[]+)\[([^\]]+)]/);
  if (match) {
    return [match[1], match[2]];
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
        className="CommonItemEditModal-modal"
        title={preparedTitle}
        visible
        width={540}
        onCancel={this.handleCancelClick}
        footer={null}
      >
        {isLoading
          ? (
            <div className="CommonItemEditModal-loading">
              Loading...
            </div>
          )
          : itemNotFound
            ? (
              <div className="CommonItemEditModal-notFound">
                Item not found
              </div>
            )
            : this.renderForm()}
      </Modal>
    );
  }

  renderForm = () => {
    const { isSaving, submitStatusMessage } = this.props;

    const preparedFields = this.getFields();
    const submitBtnClassName = cn('btn', this.shouldCreateItem ? 'btn-success' : 'btn-warning');
    const submitDisabled = ! this.isFormReadyToSubmit();

    return (
      <div className="CommonItemEditModal-form">
        <form>
          <fieldset disabled={isSaving}>
            <div className="CommonItemEditModal-fields">
              {preparedFields.map(field => {
                return (
                  <div
                    key={field.key}
                    className="form-group row"
                  >
                    {this.renderField(field)}
                  </div>
                );
              })}
            </div>

            <div className="CommonItemEditModal-buttons">
              <button
                type="submit"
                className={submitBtnClassName}
                disabled={submitDisabled}
                onClick={this.handleSubmitClick}
              >
                Submit
              </button>
              {submitStatusMessage
                ? (
                  <div className="CommonItemEditModal-submitMessage">
                    {submitStatusMessage}
                  </div>
                )
                : null}
            </div>
          </fieldset>
        </form>
      </div>
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

      default:
        return this.renderInputField(field);
    }
  };

  renderInputField = field => {
    const { formData } = this.state;
    const { hideLabels } = this.props;
    const id = `CommonItemEditModal-${field.key}`;
    const value = formData[field.key] == null ? '' : String(formData[field.key]);
    const fieldClassName = hideLabels ? 'col-sm-12' : 'col-sm-9';
    const invalid = !!field.invalidFeedback && !!field.invalid && field.invalid(formData);
    const inputClassName = cn('form-control', invalid && 'is-invalid');

    return (
      <React.Fragment>
        {hideLabels
          ? null
          : (
            <label
              htmlFor={id}
              className="col-sm-3 col-form-label"
            >
              {field.title}
            </label>
          )}
        <div className={fieldClassName}>
          <input
            id={id}
            type="text"
            name={field.key}
            value={value}
            placeholder={field.placeholder}
            disabled={field.disabled}
            onChange={this.handleInputFieldChange}
            className={inputClassName} />
          {invalid
            ? (
              <div className="invalid-feedback">
                {field.invalidFeedback}
              </div>
            )
            : null}
          {field.helpText
            ? (
              <small className="form-text text-muted">
                {field.helpText}
              </small>
            )
            : null}
        </div>
      </React.Fragment>
    );
  };

  renderCheckboxGroupField = field => {
    const { formData } = this.state;
    const { hideLabels } = this.props;
    const values = formData[field.key] || [];
    const fieldClassName = hideLabels ? 'col-sm-12' : 'col-sm-9';

    return (
      <React.Fragment>
        {hideLabels
          ? null
          : <legend className="col-form-label col-sm-3">{field.title}</legend>}
        <div className={fieldClassName}>
          {field.options.map(option => {
            const checked = values.includes(option.key);
            const optionName = getOptionFormName([field.key, option.key]);
            const id = `CommonItemEditModal-${optionName}`;

            return (
              <div
                key={option.key}
                className="form-check form-check-inline"
              >
                <input
                  id={id}
                  type="checkbox"
                  name={optionName}
                  checked={checked}
                  disabled={field.disabled}
                  onChange={this.handleCheckboxGroupChange}
                  className="form-check-input"/>
                <label
                  htmlFor={id}
                  className="form-check-label"
                >
                  {option.label}
                </label>
              </div>
            );
          })}
        </div>
      </React.Fragment>
    );
  };

  renderOptionGroupField = field => {
    const { formData } = this.state;
    const { hideLabels } = this.props;
    const value = formData[field.key];
    const fieldClassName = hideLabels ? 'col-sm-12' : 'col-sm-9';

    return (
      <React.Fragment>
        {hideLabels
          ? null
          : <legend className="col-form-label col-sm-3">{field.title}</legend>}
        <div className={fieldClassName}>
          {field.options.map(option => {
            const checked = value === option.key;
            const optionName = getOptionFormName([field.key, option.key]);
            const id = `CommonItemEditModal-${optionName}`;

            return (
              <div
                key={option.key}
                className="form-check"
              >
                <input
                  id={id}
                  type="radio"
                  name={field.key}
                  value={option.key}
                  checked={checked}
                  disabled={field.disabled}
                  onChange={this.handleOptionGroupChange}
                  className="form-check-input"/>
                <label
                  htmlFor={id}
                  className="form-check-label"
                >
                  {option.label}
                </label>
              </div>
            );
          })}
        </div>
      </React.Fragment>
    );
  };

  handleInputFieldChange = event => {
    const { formData } = this.state;
    const { target } = event;

    this.setState({ formData: { ...formData, [target.name]: target.value } });
  };

  handleCheckboxGroupChange = event => {
    const { formData } = this.state;
    const { target } = event;

    const [fieldName, optionName] = parseOptionFormName(target.name);
    const values = formData[fieldName];
    const newValues = target.checked
      ? [...values, optionName]
      : values.filter(option => option !== optionName);

    this.setState({ formData: { ...formData, [fieldName]: newValues } });
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
