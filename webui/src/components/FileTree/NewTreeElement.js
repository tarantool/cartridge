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
import { validateFileNameExtention } from 'src/misc/files.utils';

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
  initialValue?: string,
  level?: number,
  type: 'file' | 'folder',
  onCancel: () => void,
  onConfirm: (id: string) => void
}

type NewTreeElementState = {
  value: string
}

export class NewTreeElement extends React.Component<NewTreeElementProps, NewTreeElementState> {
  constructor(props: NewTreeElementProps) {
    super(props);

    this.state = {
      value: (props.initialValue) || ''
    }
  }

  inputRef = React.createRef<Input>()

  componentDidMount() {
    if (this.inputRef.current) {
      this.inputRef.current.focus();
    }
  }

  enabledSymbolsRegEx = /^([A-Za-z0-9-._]){0,32}$/;

  handleChange = (event: InputEvent) => {
    if (event.target instanceof HTMLInputElement) {
      const { value } = event.target;

      if (this.enabledSymbolsRegEx.test(value)) {
        this.setState({ value });
      }
    }
  }

  handleKeyPress = (event: KeyboardEvent) => {
    const { value } = this.state;
    const { type } = this.props;

    if (event.keyCode === 13) {
      if (type === 'file') {
        if (validateFileNameExtention(value)) {
          this.props.onConfirm(value);
        }
      } else {
        this.props.onConfirm(value);
      }
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
      initialValue,
      level,
      type,
      onCancel,
      onConfirm
    } = this.props;

    const { value } = this.state;

    const Icon = type === 'folder' ? IconFolder : IconFile;

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
          title={initialValue}
        >
          <IconChevron
            className={cx(styles.iconChevron, { [styles.iconChevronFile]: type !== 'folder' })}
            direction={expanded ? 'down' : 'right'}
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
