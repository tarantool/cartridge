import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import CommonItemEditModal from 'src/components/CommonItemEditModal';
import CommonItemList from 'src/components/CommonItemList';
import message from 'src/misc/message';

const prepareColumnProps =(fields, handleEditItemClick, handleDeleteItemClick) => {
  const columns = fields.map(field => {
    const { customProps = {}, ...other } = field;
    return {
      ...other,
      ...customProps.list,
    };
  });

  return [
    ...columns,
    {
      title: 'Actions',
      key: 'actions',
      render: record => {
        const handleEditClick = handleEditItemClick ? event => handleEditItemClick({ event, record }) : null;
        const handleDeleteClick = handleDeleteItemClick ? event => handleDeleteItemClick({ event, record }) : null;

        return (
          <React.Fragment>
            {handleEditClick
              ? (
                <button
                  type="button"
                  className="btn btn-link"
                  onClick={handleEditClick}
                >
                  Edit
                </button>
              )
              : null}
            {handleDeleteClick
              ? (
                <button
                  type="button"
                  className="btn btn-link"
                  onClick={handleDeleteClick}
                >
                  Delete
                </button>
              )
              : null}
          </React.Fragment>
        );
      },
      align: 'center',
      width: '20em',
    },
  ];
};

const prepareFieldProps = fields => {
  return fields.map(field => {
    const { customProps = {}, ...other } = field;
    return {
      ...other,
      ...customProps.forms,
      customProps: {
        create: customProps.createForm,
        edit: customProps.editForm,
      },
    };
  });
};

class CommonItemManagement extends React.PureComponent {
  constructor(props) {
    super(props);

    this.state = {
      editableItem: null,
      creatingItem: false,
    };

    this.prepareColumnProps = defaultMemoize(prepareColumnProps);
    this.prepareFieldProps = defaultMemoize(prepareFieldProps);
  }

  render() {
    const { itemKey, listHeader, renderLeftButtons, renderRightButtons, createItemButtonText, dataSource } = this.props;
    const { creatingItem, editableItem } = this.state;

    const itemEditModalVisible = !!editableItem || creatingItem;
    const leftButtons = renderLeftButtons && renderLeftButtons();
    const rightButtons = renderRightButtons && renderRightButtons();
    const columnProps = this.getColumnProps();

    return (
      <React.Fragment>
        {itemEditModalVisible
          ? this.renderItemEditModal()
          : null}
        <div className="tr-cards-margin">
          <div className="tr-cards-head">
            <div className="tr-cards-header">
              {listHeader}
            </div>
            <div className="tr-cards-buttons">
              {leftButtons}
              <button
                type="button"
                className="btn btn-light btn-sm"
                onClick={this.handleCreateItemClick}
              >
                {createItemButtonText}
              </button>
              {rightButtons}
            </div>
          </div>
          <CommonItemList
            rowKey={itemKey}
            columns={columnProps}
            dataSource={dataSource} />
        </div>
      </React.Fragment>
    );
  }

  renderItemEditModal = () => {
    const { editModalTitle, getItemDefaultDataSource } = this.props;
    const { creatingItem, editableItem } = this.state;

    const fieldProps = this.getFieldProps();
    const dataSource = creatingItem
      ? getItemDefaultDataSource ? this.getItemDefaultDataSource() : null
      : editableItem;

    return (
      <CommonItemEditModal
        title={editModalTitle}
        fields={fieldProps}
        shouldCreateItem={creatingItem}
        dataSource={dataSource}
        onSubmit={this.handleItemSubmit}
        onRequestClose={this.handleModalClose} />
    );
  };

  updateList = () => {
    const { onGetListRequest } = this.props;
    onGetListRequest();
  };

  handleCreateItemClick = () => {
    this.setState({ creatingItem: true });
  };

  handleEditItemClick = eventProps => {
    const { record } = eventProps;
    this.setState({ editableItem: record });
  };

  handleDeleteItemClick = async eventProps => {
    const { record } = eventProps;
    const { deleteItem } = this.props;
    try {
      await deleteItem(record);
      message.success('Deleted successfully');
      this.updateList();
    }
    catch (error) {
      message.error(error[0].message);
    }
  };

  handleItemSubmit = async item => {
    const { creatingItem } = this.state;

    if (creatingItem) {
      const { createItem } = this.props;
      this.setState({ creatingItem: false });
      try {
        await createItem(item);
        message.success('Created successfully');
        this.updateList();
      }
      catch (error) {
        message.error(error[0].message);
      }
    }
    else {
      const { editItem } = this.props;
      this.setState({ editableItem: null });
      try {
        await editItem(item);
        message.success('Edited successfully');
        this.updateList();
      }
      catch (error) {
        message.error(error[0].message);
      }
    }
  };

  handleModalClose = () => {
    const { creatingItem } = this.state;
    if (creatingItem) {
      this.setState({ creatingItem: false });
    } else {
      this.setState({ editableItem: null });
    }
  };

  getColumnProps = () => {
    const { fields, editItem, deleteItem } = this.props;
    const handleEditItemClick = editItem ? this.handleEditItemClick : null;
    const handleDeleteItemClick = deleteItem ? this.handleDeleteItemClick : null;
    return this.prepareColumnProps(fields, handleEditItemClick, handleDeleteItemClick);
  };

  getFieldProps = () => {
    const { fields } = this.props;
    return this.prepareFieldProps(fields);
  };

  getItemDefaultDataSource = () => {
    const { dataSource, getItemDefaultDataSource } = this.props;
    return getItemDefaultDataSource(dataSource);
  };
}

CommonItemManagement.propTypes = {
  itemKey: PropTypes.string.isRequired,
  listHeader: PropTypes.string.isRequired,
  createItemButtonText: PropTypes.string,
  editModalTitle: PropTypes.any,
  fields: PropTypes.arrayOf(PropTypes.shape({
    customProps: PropTypes.shape({
      forms: PropTypes.object,
      createForm: PropTypes.object,
      editForm: PropTypes.object,
      list: PropTypes.object,
    }),
  })).isRequired,
  renderLeftButtons: PropTypes.func,
  renderRightButtons: PropTypes.func,
  dataSource: PropTypes.arrayOf(PropTypes.object),
  onGetListRequest: PropTypes.func.isRequired,
  getListRequestStatus: PropTypes.shape({
    loading: PropTypes.bool,
    loaded: PropTypes.bool,
    error: PropTypes.object,
  }),
  createItem: PropTypes.func.isRequired,
  editItem: PropTypes.func,
  deleteItem: PropTypes.func,
  selectedItemKey: PropTypes.oneOfType([
    PropTypes.string,
    PropTypes.number,
  ]),
  getItemDefaultDataSource: PropTypes.func,
};

CommonItemManagement.defaultProps = {
  createItemButtonText: 'Create',
};

export default CommonItemManagement;
