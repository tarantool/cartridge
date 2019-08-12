import * as React from 'react';
import { Button, IconMore } from '@tarantool.io/ui-kit';
import { css } from 'emotion';
import styled from 'react-emotion';

const defaultListItemColor = 'rgba(0, 0, 0, 0.65)';

const styles = css`
  position: relative;
`

const DropdownList = styled.ul`
  position: absolute;
  margin-top: 6px;
  right: 0;
  top: 100%;
  padding: 8px 0;
  border-radius: 4px;
  box-shadow: 0 5px 20px 0 rgba(0, 0, 0, 0.09);
  border: solid 1px rgba(82, 82, 82, 0.07);
  background-color: #ffffff;
  z-index: 3;
`;

const DropdownListItem = styled.li`
  padding: 0 16px;
  list-style: none;
  font-size: 14px;
  line-height: 32px;
  white-space: nowrap;
  color: ${({ color }) => color};

  &:hover {
    cursor: pointer;
    background-color: #fafafa;
  }
`

type MenuItemProps = {
  text?: string,
  color?: string,
  className?: string,
  onClick?: (MouseEvent) => void
}

type DropdownProps = {
  className?: string,
  items?: MenuItemProps[],
  size?: string,
  disabled?: boolean,
};

class Dropdown extends React.Component<DropdownProps> {
  state = {
    isOpen: false
  };

  componentDidMount() {
    document.addEventListener('mousedown', this.handleClickOutside);
  }

  componentWillUnmount() {
    document.removeEventListener('mousedown', this.handleClickOutside);
  }

  setDropdownRef = (node: React.Node) => {
    this.dropdownRef = node;
  }

  handleClickOutside = (event: MouseEvent) => {
    const { isOpen } = this.state;
    const ref = this.dropdownRef;

    if (isOpen && ref && !ref.contains(event.target)) {
      this.toggleDropdown();
    }
  }

  toggleDropdown = () => this.setState(({ isOpen }) => ({ isOpen: !isOpen }));

  renderDropdownList = (items: MenuItemProps) => (
    <DropdownList>
      {items.map((
        {
          text,
          className,
          color = defaultListItemColor,
          onClick
        },
        index
      ) => (
        <DropdownListItem
          className={className}
          key={index}
          onClick={() => onClick(items[index])}
          color={color}
        >
          {text}
        </DropdownListItem>
      ))}
    </DropdownList>
  );

  render() {
    const { items, className, size, children } = this.props;
    const { isOpen } = this.state;

    return (
      <div
        css={styles}
        ref={this.setDropdownRef}
        onClick={this.toggleDropdown}
        className={className}
      >
        {isOpen && this.renderDropdownList(items)}
        {
          children
            ? children
            : (
              <Button
                icon={IconMore}
                intent='iconic'
                size={size}
              />
            )
        }
      </div>
    )
  }
}

export default Dropdown;
