import React from 'react';
import { css, cx } from 'emotion';
import Button from 'src/components/Button';
import { Title } from 'src/components/styled';

const styles = {
  head: css`
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    align-items: center;
    padding: 1em 0 1em 5px;
    font-size: 1.4em;
  `,
  headThin: css`
    padding-bottom: 0.4em;
    padding-top: 0;
  `,
  buttons: css`
    display: flex;
  `,
  button: css`
    display: block;
    margin-right: 25px;
    :last-child{
      margin-right: 0px;
    }
  `
};

export const HeadButton = props => <Button {...props} size="large" />;

const PageSectionHead = ({
  buttons,
  children,
  thin,
  title
}) => (
  <div className={cx(styles.head, { [styles.headThin]: thin })}>
    {!!title && <Title>{title}</Title>}
    {!!buttons && (
      <div className={styles.buttons}>
        {buttons instanceof Array
          ? buttons.map(button => button ? <div className={styles.button}>{button}</div> : null)
          : <div className={styles.button}>{buttons}</div>}
      </div>
    )}
    {children}
  </div>
);

export default PageSectionHead;
