// @flow
// TODO: move to uikit
import * as React from 'react';
import { css, cx } from 'emotion';
import ControlsPanel from 'src/components/ControlsPanel';
import Text from 'src/components/Text';

const styles = {
  section: css`
    margin: 0 0 48px;
  `,
  headingPane: css`
    display: flex;
    flex-direction: row;
    align-items: baseline;
  `,
  headingPaneMargin: css`
    margin-bottom: 24px;
  `,
  heading: css`
    /* display: inline; */
  `,
  subTitle: css`
    margin-left: 32px;
  `,
  topRightControls: css`
    margin-left: auto;
  `
};

type PageSectionProps = {
  children?: React.Node,
  className?: string,
  subTitle?: string | React.Node,
  title?: string | React.Node,
  topRightControls?: React.Node
};

const PageSection = ({
  children,
  className,
  subTitle,
  title,
  topRightControls
}:
PageSectionProps) => {
  const isHeadingPaneVisible = title || subTitle || topRightControls;

  return (
    <section className={cx(styles.section, className)}>
      {isHeadingPaneVisible && (
        <div
          className={cx(
            styles.headingPane,
            { [styles.headingPaneMargin]: children }
          )}
        >
          {title && (<Text className={styles.heading} variant='h2'>{title}</Text>)}
          {subTitle && (<Text className={styles.subTitle} variant='h5' tag='span' upperCase>{subTitle}</Text>)}
          {topRightControls && <ControlsPanel className={styles.topRightControls}>{topRightControls}</ControlsPanel>}
        </div>
      )}
      {children}
    </section>
  );
};

export default PageSection;
