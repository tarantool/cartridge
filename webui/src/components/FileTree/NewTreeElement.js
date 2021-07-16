// @flow
import * as React from 'react';
import { cx } from '@emotion/css';
import {
  IconChevron,
  IconFile,
  IconFolder,
  Input,
  withTooltip
} from '@tarantool.io/ui-kit';
import { styles } from './styles';

const ListItemWithTooltip = withTooltip('li');

type NewTreeElementProps = {
  active?: boolean,
  children?: React.Node,
  className?: string,
  expanded?: boolean,
  filePaths: string[],
  parentPath?: string,
  initialValue?: string,
  level?: number,
  type: 'file' | 'folder',
  onCancel: () => void,
  onConfirm: (id: string) => void
}

type NewTreeElementState = {
  value: string,
  fileExistsError: boolean
}

export class NewTreeElement extends React.Component<NewTreeElementProps, NewTreeElementState> {
  constructor(props: NewTreeElementProps) {
    super(props);

    const value = (props.initialValue) || '';
    this.state = { value, fileExistsError: false };
    this.state.fileExistsError = this.isFileExists(
      value,
      props.parentPath,
      props.initialValue,
      props.filePaths
    );
  }

  inputRef = React.createRef<Input>()

  componentDidMount() {
    if (this.inputRef.current) {
      this.inputRef.current.focus();
    }
  }

  enabledSymbolsRegEx = /^([A-Za-z0-9-._]){0,32}$/;

  isFileExists = (
    name: string,
    parentPath: ?string,
    initial: ?string,
    paths: string[]
  ) => !!name
    && initial !== name
    && paths.includes((parentPath ? (parentPath + '/') : '') + name);

  handleChange = (event: InputEvent) => {
    if (event.target instanceof HTMLInputElement) {
      const { value } = event.target;

      if (this.enabledSymbolsRegEx.test(value)) {
        const { initialValue, filePaths, parentPath } = this.props;

        this.setState({
          value,
          fileExistsError: this.isFileExists(
            value,
            parentPath,
            initialValue,
            filePaths
          )
        });
      }
    }
  }

  handleBlur = (event: FocusEvent) => {
    const { value } = this.state;

    this.props.onConfirm(value);
  }

  handleKeyPress = (event: KeyboardEvent) => {
    const { value } = this.state;
    const { type } = this.props;

    if (event.keyCode === 13) {
      if (type === 'file') {
        // if (validateFileNameExtension(value))
        this.props.onConfirm(value);
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
      type
    } = this.props;

    const { fileExistsError, value } = this.state;

    const Icon = type === 'folder' ? IconFolder : IconFile;

    return (
      <React.Fragment>
        <ListItemWithTooltip
          className={cx(
            styles.row,
            styles.newRow,
            { [styles.active]: active },
            className
          )}
          style={{
            paddingLeft: (level || 0) * 20
          }}
          title={initialValue}
          tooltipContent={fileExistsError ? 'The name already exists' : undefined}
        >
          <IconChevron
            className={cx(
              styles.iconChevron,
              {
                [styles.iconChevronHidden]: type !== 'folder'
                  || !children
                  || (children instanceof Array && !children.length)
              }
            )}
            direction={expanded ? 'down' : 'right'}
          />
          <Icon className={styles.fileIcon} opened={expanded} />
          <Input
            error={fileExistsError}
            ref={this.inputRef}
            value={value}
            onChange={this.handleChange}
            onBlur={this.handleBlur}
            onKeyDown={this.handleKeyPress}
            size='m'
          />
        </ListItemWithTooltip>
        {expanded && children}
      </React.Fragment>
    );
  }
}
