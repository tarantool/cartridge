// @flow
// TODO: move to uikit
import * as React from 'react';
import { css } from 'react-emotion';
import { IconLink } from 'src/components/Icon';
import LeaderFlag from 'src/components/LeaderFlag';
import Text from 'src/components/Text';
import HealthStatus from 'src/components/HealthStatus';
import { withRouter } from 'react-router-dom'

const styles = {
  item: css`
    position: relative;
    padding: 12px 16px 12px 32px;
    border: solid 1px #E8E8E8;
    margin-bottom: 18px;
    border-radius: 4px;
    background-color: #ffffff;
    transition: 0.1s ease-in-out;
    transition-property: border-color, box-shadow;
    box-shadow: 0 1px 10px 0 rgba(0, 0, 0, 0.06);
  `,
  row: css`
    display: flex;
    align-items: baseline;
    margin-bottom: 4px;
  `,
  heading: css`
    margin-right: 12px;
    min-width: 50%;
  `,
  leaderFlag: css`
    position: absolute;
    top: 0;
    left: 3px;
  `,
  uriWrap: css`
    display: flex;
    align-items: center;
  `,
  uriIcon: css`
    margin-right: 4px;
  `,
};

class ServerInfoMmodal extends React.PureComponent {
  render() {
    const {
      status,
      uri,
      alias,
      message,
      master,
    } = this.props;

    return (
      <div className={styles.item}>
        <div className={styles.row}>
          {master && (
            <LeaderFlag className={styles.leaderFlag} />
          )}
          <div className={styles.heading}>
            <Text variant='h4'>{alias}</Text>
            <div className={styles.uriWrap}>
              <IconLink className={styles.uriIcon} />
              <Text variant='h5' tag='span'>{uri}</Text>
            </div>
          </div>
          <HealthStatus status={status} message={message} />
        </div>
      </div>
    )
  }
}

export default withRouter(ServerInfoMmodal);
