import PropTypes from 'prop-types';
import React from 'react';
import { defaultMemoize } from 'reselect';

import cn from 'src/misc/cn';

import './CommonItemList.css';

const getRowStyle = column => {
  if (column.width) {
    if (typeof column.width === 'string') {
      return {
        minWidth: column.width,
        maxWidth: column.width,
      };
    }
    else {
      return {
        flex: column.width
      };
    }
  }
  return null;
};

const prepareColumns = columns => {
  return columns.filter(column => ! column.hidden);
};

class CommonItemList extends React.PureComponent {
  constructor(props) {
    super(props);

    this.prepareColumns = defaultMemoize(prepareColumns);
  }

  render() {
    const { skin, shouldRenderHead, shouldRenderRowHeads, isLoading } = this.props;
    const className = cn(
      'trTable',
      skin && `trTable-skin--${skin}`,
      shouldRenderRowHeads && 'trTable-skin--rowHeads',
    );

    return (
      <div className={className}>
        {shouldRenderHead
          ? this.renderHead()
          : null}
        {isLoading
          ? (
            <div className="trTable-loading">
              Loading...
            </div>
          )
          : this.renderData()}
      </div>
    );
  }

  renderHead = () => {
    const columns = this.getColumns();

    return (
      <div className="trTable-head">
        {columns.map(this.renderHeadCell)}
      </div>
    );

  };

  renderHeadCell = column => {
    const innerClassName = cn(
      'trTable-cellInner trTable-headCellInner',
      column.align && `trTable-cell--${column.align}Align`,
    );

    const style = getRowStyle(column);

    return (
      <div
        key={column.key}
        className="trTable-cellOuter trTable-headCellOuter"
        style={style}
      >
        <div className={innerClassName}>
          {column.title}
        </div>
      </div>
    );
  };

  renderData = () => {
    const { dataSource } = this.props;
    const shouldRenderRows = !!dataSource && dataSource.length > 0;

    return shouldRenderRows
      ? this.renderRows()
      : (
        <div className="trTable-noData">
          No data
        </div>
      );
  };

  renderRows = () => {
    const { shouldRenderRowHeads, dataSource } = this.props;
    const columns = this.getColumns();

    return (
      <div className="trTable-rows">
        {dataSource.map(
          shouldRenderRowHeads
            ? record => {
              return [
                this.renderRowHead(record),
                this.renderRow(record, columns),
              ];
            }
            : record => this.renderRow(record, columns)
        )}
      </div>
    );
  };

  renderRowHead = record => {
    const { rowKey, rowHead } = this.props;

    const key = `rowHead-${record[rowKey]}`;
    const headParts = [];

    if (rowHead.name) {
      headParts.push(
        <span key="__name__" className="trTable-rowHeadName">
          {rowHead.name(record)}
        </span>
      );
    }

    const labels = rowHead.labels
      ? rowHead.labels
        .map(label => {
          const value = record[label.key];
          return value
            ? (
              <span key={label.name} className="trTable-rowHeadLabel">
                <span className="trTable-rowHeadLabelName">{label.name}:</span>
                <span className="trTable-rowHeadLabelValue">{value}</span>
              </span>
            )
            : null;
        })
        .filter(Boolean)
      : [];
    headParts.push(...labels);

    return (
      <div
        key={key}
        className="trTable-rowHead"
      >
        {headParts.length
          ? headParts
          : 'Untitled'}
      </div>
    );
  };

  renderRow = (record, columns) => {
    const { rowKey } = this.props;
    const key = record[rowKey];

    return (
      <div
        key={key}
        className="trTable-row"
      >
        {columns.map(column => this.renderCell(record, column))}
      </div>
    );
  };

  renderCell = (record, column) => {
    let content;
    if (column.render) {
      const { dataSource } = this.props;
      content = column.render(record, dataSource);
    }
    else if (column.renderText) {
      const { dataSource } = this.props;
      content = (
        <div className="trTable-cellText">
          {column.renderText(record, dataSource)}
        </div>
      );
    }
    else {
      const value = record[column.key];
      content = (
        <div className="trTable-cellText">
          {value == null ? column.defaultValue : value}
        </div>
      );
    }

    const innerClassName = cn(
      'trTable-cellInner trTable-rowCellInner',
      column.align && `trTable-cell--${column.align}Align`,
    );

    const style = getRowStyle(column);

    return (
      <div
        key={column.key}
        className="trTable-cellOuter trTable-rowCellOuter"
        style={style}
      >
        <div className={innerClassName}>
          {content}
        </div>
      </div>
    );
  };

  getColumns = () => {
    const { columns } = this.props;
    return this.prepareColumns(columns);
  };
}

CommonItemList.propTypes = {
  skin: PropTypes.oneOf(['regular', 'light']),
  rowKey: PropTypes.string,
  shouldRenderHead: PropTypes.bool,
  shouldRenderRowHeads: PropTypes.bool,
  rowHead: PropTypes.shape({
    name: PropTypes.func,
    labels: PropTypes.arrayOf(PropTypes.shape({
      key: PropTypes.string.isRequired,
      name: PropTypes.string.isRequired,
    })),
  }),
  columns: PropTypes.arrayOf(PropTypes.shape({
    key: PropTypes.string.isRequired,
    hidden: PropTypes.bool,
    title: PropTypes.string,
    align: PropTypes.oneOf(['right', 'center', 'left']),
    width: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
    defaultValue: PropTypes.string,
    renderText: PropTypes.func,
    render: PropTypes.func,
  })),
  isLoading: PropTypes.bool,
  dataSource: PropTypes.arrayOf(PropTypes.object),
  dispatch: PropTypes.func,
};

CommonItemList.defaultProps = {
  shouldRenderHead: true,
  shouldRenderRowHeads: false,
  isLoading: false,
};

export default CommonItemList;
