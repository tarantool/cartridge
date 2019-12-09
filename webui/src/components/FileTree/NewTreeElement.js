// @flow
import * as React from 'react';
import { connect } from 'react-redux';
import { css, cx } from 'emotion';
import {
  Button,
  ControlsPanel,
  IconChevron,
  IconFile,
  IconFolder,
  Input,
  Text
} from '@tarantool.io/ui-kit';
import type { TreeFileItem } from 'src/store/selectors/filesSelectors';
import type { FileItem } from 'src/store/reducers/files.reducer';

const styles = {
  element: css`
    position: relative;
    display: flex;
    flex-wrap: nowrap;
    justify-content: flex-start;
    align-items: center;
    height: 34px;
    padding-right: 8px;
    user-select: none;
    cursor: pointer;

    &:hover {
      background-color: #ffffff;
    }

    .NewTreeElement__btns {
      display: none;
    }

    &:hover > .NewTreeElement__btns {
      display: flex;
    }
  `,
  active: css`
    background-color: #ffffff;
  `,
  iconChevron: css`
    margin: 4px;
    fill: rgba(0, 0, 0, 0.65);
  `,
  iconChevronFile: css`
    visibility: hidden;
  `,
  fileIcon: css`
    margin: 4px;
  `,
};

type NewTreeElementProps = {
  active?: boolean,
  children?: React.Node,
  className?: string,
  expanded?: boolean,
  file: FileItem,
  level?: number,
  onCancel: () => void,
  onConfirm: (id: string) => void
}

type NewTreeElementState = {
  value: string
}

export class NewTreeElement extends React.Component<NewTreeElementProps, NewTreeElementState> {
  constructor(props) {
    super(props);

    this.state = {
      value: (props.file && props.file.fileName) || ''
    }
  }

  inputRef = React.createRef();

  componentDidMount() {
    if (this.inputRef.current) {
      this.inputRef.current.focus();
    }
  }

  enabledSymbolsRegEx = /^([A-Za-z0-9-._]){0,32}$/;

  handleChange = (event: InputEvent) => {
    const { value } = event.target;

    if (this.enabledSymbolsRegEx.test(value)) {
      this.setState({ value });
    }
  }

  handleKeyPress = (event: KeyboardEvent) => {
    if (event.keyCode === 13) {
      this.props.onConfirm(this.state.value);
    } else if (event.keyCode === 27) {
      this.props.onCancel();
    }
  }

  render() {
    const {
      active,
      className,
      children,
      expanded,
      file,
      level,
      onCancel,
      onConfirm
    } = this.props;

    const { value } = this.state;

    const Icon = file.type === 'folder' ? IconFolder : IconFile;

    return (
      <React.Fragment>
        <li
          className={cx(
            styles.element,
            { [styles.active]: active },
            className
          )}
          style={{
            paddingLeft: (level || 0) * 20
          }}
          title={file.fileName}
        >
          <IconChevron
            className={cx(styles.iconChevron, { [styles.iconChevronFile]: file.type !== 'folder' })}
            direction={expanded ? 'down' : 'right' }
          />
          <Icon className={styles.fileIcon} opened={expanded} />
          <Input
            ref={this.inputRef}
            value={value}
            onChange={this.handleChange}
            onBlur={this.props.onCancel}
            onKeyDown={this.handleKeyPress}
          />
        </li>
        {expanded && children}
      </React.Fragment>
    );
  }
}
