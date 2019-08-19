// @flow
import * as React from 'react';
import { defaultMemoize } from 'reselect';
import ReactDragListView from 'react-drag-listview';
import { Form, Row, Table, Typography } from 'antd';
import { css } from 'emotion';
import Button from 'src/components/Button';
import Checkbox from './Checkbox';
import Input from './Input';
import Radio from './Radio';
import PopupFooter from './PopupFooter';
import FormField from 'src/components/FormField';

type FormData = { [key: string]: string | string[] };

type CommonItemEditFormFieldOptions = Array<{
  key: string,
  label: string | React.Component<any>,
  disabled?: boolean
}>;

export type CommonItemEditFormField = {
  key: string,
  hidden?: boolean | (d: FormData) => boolean,
  type?: 'input' | 'checkboxGroup' | 'optionGroup' | 'draggableList',
  options?: CommonItemEditFormFieldOptions | (d: FormData) => CommonItemEditFormFieldOptions,
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

type NormalizedField = {
  ...$Exact<CommonItemEditFormField>,
  disabled: ?boolean,
  helpText: ?string,
  hidden: ?boolean,
  options: ?CommonItemEditFormFieldOptions,
  title: ?string
};

const { Text } = Typography;

const styles = {
  footer: css`
    display: flex;
    flex-direction: row;
    align-items: center;
  `,
  message: css`
    margin-left: 24px;
  `,
  fieldset: css`
    border: none;
    margin: 0;
    padding: 0;
  `
};

const formItemLayout = {
  labelCol: {
    span: 5
  },
  wrapperCol: {
    span: 19
  }
};

const normalizeProp = (prop, dataSource: FormData) => typeof prop === 'function' ? prop(dataSource) : prop;

const pickByField = (
  fields: CommonItemEditFormField[],
  name: string
): ?CommonItemEditFormField => fields.find(({ key }) => key === name);

const prepareFields = (shouldCreateItem, fields, formData) => fields
  .map(field => {
    const { customProps = {}, ...other } = field;
    return {
      ...other,
      ...(shouldCreateItem ? customProps.create : customProps.edit)
    };
  })
  .map(field => {
    return {
      ...field,
      hidden: normalizeProp(field.hidden, formData),
      options: normalizeProp(field.options, formData),
      disabled: normalizeProp(field.disabled, formData),
      title: normalizeProp(field.title, formData),
      helpText: normalizeProp(field.helpText, formData)
    };
  })
  .filter(field => ! field.hidden);

type CommonItemEditFormProps = {
  errorMessage: ?string,
  isLoading: ?boolean,
  isSaving: ?boolean,
  itemNotFound: ?boolean,
  shouldCreateItem: ?boolean,
  fields: CommonItemEditFormField[],
  hideLabels: ?boolean,
  dataSource: ?FormData,
  isFormReadyToSubmit: ?(d: ?FormData) => boolean,
  submitStatusMessage: ?string,
  onSubmit: (d: FormData) => void
};

type CommonItemEditFormState = {
  formData: ?FormData,
  controlled: boolean
}
class CommonItemEditForm extends React.PureComponent<CommonItemEditFormProps, CommonItemEditFormState> {
  shouldCreateItem: boolean;

  static defaultProps = {
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

  constructor(props: CommonItemEditFormProps) {
    super(props);

    this.shouldCreateItem = !!props.shouldCreateItem;
  }

  static getDerivedStateFromProps(props: CommonItemEditFormProps, state: CommonItemEditFormState) {
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
    const { isLoading, itemNotFound } = this.props;

    return (
      isLoading
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
          : this.renderForm()
    );
  }

  renderForm = () => {
    const {
      errorMessage,
      hideLabels,
      isSaving,
      submitStatusMessage
    } = this.props;
    const preparedFields = this.getFields();
    const submitDisabled = ! this.isFormReadyToSubmit();

    return (
      <Form onSubmit={this.handleSubmitClick}>
        <fieldset className={styles.fieldset} disabled={isSaving}>
          {preparedFields.map(field => (
            <FormField
              key={field.key}
              label={!hideLabels && field.title}
              labelAlign="left"
              validateStatus={
                !!field.invalidFeedback
                  && !!field.invalid
                  && field.invalid(this.state.formData)
                  && 'error'
              }
              help={field.invalidFeedback || field.helpText}
              {...(hideLabels ? {} : formItemLayout)}
            >
              {this.renderField(field)}
            </FormField>
          ))}

          <PopupFooter
            className={styles.footer}
            controls={(
              <Button
                disabled={submitDisabled}
                intent="primary"
                onClick={this.handleSubmitClick}
                type="submit"
              >
                Submit
              </Button>
            )}
          >
            {(errorMessage || submitStatusMessage) && <Text>{errorMessage || submitStatusMessage}</Text>}
          </PopupFooter>
        </fieldset>
      </Form>
    );
  };

  isFormReadyToSubmit = () => {
    const { isFormReadyToSubmit } = this.props;
    if (isFormReadyToSubmit) {
      return isFormReadyToSubmit(this.state.formData);
    }
    return true;
  };

  renderField = (field: NormalizedField) => {
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

  renderDraggableList = (field: NormalizedField) => {
    const { formData } = this.state;
    if (!(field && field.dataSource) || !formData) return null;

    const dragProps = {
      onDragEnd: (fromIndex, toIndex) => {
        const handler = field.stateModifier ? field.stateModifier : (_, state, fromIndex, toIndex) => state;

        this.setState(prevState => {
          const { formData } = prevState;
          if (!formData) return null;

          const value = formData[field.key];
          const data = value instanceof Array ? [...value] : [value];
          const item = data.splice(fromIndex, 1)[0];
          data.splice(toIndex, 0, item);

          return {
            formData: handler(formData, { ...formData, [field.key]: data }, fromIndex, toIndex)
          }
        });
      },
      handleSelector: 'a'
    };

    return (
      <ReactDragListView {...dragProps}>
        <Table
          columns={field.tableColumns}
          pagination={false}
          dataSource={formData[field.dataSource]}
          {...field.tableProps}
        />
      </ReactDragListView>
    )
  };


  renderInputField = (field: NormalizedField) => {
    const { formData } = this.state;
    if (!formData) return null;
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

  renderCheckboxGroupField = (field: NormalizedField): React$Element<Row>[] => {
    const { formData } = this.state;
    if (!formData || !field.options) return [];

    const values = formData[field.key] || [];

    return (field.options || []).map(option => (
      <Row key={option.key}>
        <Checkbox
          name={field.key}
          value={option.key}
          checked={values.includes(option.key)}
          disabled={field.disabled || option.disabled}
          onChange={this.handleCheckboxGroupChange}
        >
          {option.label}
        </Checkbox>
      </Row>
    ));
  };

  renderOptionGroupField = (field: NormalizedField): React$Element<Row>[] => {
    const { formData } = this.state;
    if (!formData || !field.options) return [];

    const value = formData[field.key];

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

  handleInputFieldChange = (event: SyntheticInputEvent<HTMLInputElement>) => {
    const { formData } = this.state;
    const { target } = event;

    this.setState({ formData: { ...formData, [target.name]: target.value } });
  };

  handleCheckboxGroupChange = (event: SyntheticInputEvent<HTMLInputElement>) => {
    const { target } = event;

    const currentField = pickByField(this.props.fields, target.name);
    if (!currentField) return;

    const handler = currentField.stateModifier ? currentField.stateModifier : (_, state) => state;

    this.setState(prevState => {
      const { formData } = prevState;
      if (!formData) return null;

      const values = formData[target.name];
      if (!(values instanceof Array)) return null;

      const newValues = target.checked
        ? [...values, target.value]
        : values.filter(option => option !== target.value);

      return {
        formData: handler(formData, { ...formData, [target.name]: newValues })
      };
    });
  };

  handleOptionGroupChange = (event: SyntheticInputEvent<HTMLSelectElement>) => {
    const { target } = event;

    const currentField = pickByField(this.props.fields, target.name);
    if (!currentField) return;

    const handler = currentField.stateModifier ? currentField.stateModifier : (_, state) => state;

    this.setState(prevState => {
      const { formData } = this.state;
      if (!formData) return null;

      return {
        formData: handler(formData, { ...formData, [target.name]: target.value })
      };
    });
  };

  handleSubmitClick = (event: MouseEvent) => {
    event.preventDefault();
    const { onSubmit } = this.props;
    const { formData } = this.state;
    if (formData) onSubmit(formData);
  };

  getFields = () => {
    const { fields } = this.props;
    const { formData } = this.state;
    return this.prepareFields(this.shouldCreateItem, fields, formData);
  };

  prepareFields = defaultMemoize(prepareFields);
}

export default CommonItemEditForm;
