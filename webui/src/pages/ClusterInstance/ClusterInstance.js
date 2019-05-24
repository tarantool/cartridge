import React from 'react';
import { css } from 'emotion';
import { Route, Switch, Redirect } from 'react-router-dom';
import HealthIndicator from 'src/components/HealthIndicator'
import SubNavMenu from 'src/components/SubNavMenu'
import ClusterInstanceSection from './child/ClusterInstanceSection';
import PageSectionHead from 'src/components/PageSectionHead';

const styles = {
  indicator: css`
    margin-right: 8px;
  `,
  headerSecondRow: css`
    flex-basis: 100%;
    display: flex;
    justify-content: space-between;
  `,
  headerError: css`
    color: #FF272C;
  `,
  layout: css`
    display: flex;
  `,
  menu: css`
    flex-shrink: 0;
    width: 180px;
  `,
  sectionContent: css`
    flex-grow: 1;
    padding: 18px;
    margin-left: 18px;
    border-radius: 4px;
    background-color: white;
  `,
};

class ClusterConfig extends React.Component {
  componentDidMount() {
    this.props.pageDidMount({
      instanceUUID: this.props.instanceUUID
    });
  }

  componentWillUnmount() {
    this.props.resetPageState();
  }

  render() {
    const {
      alias,
      instanceUUID,
      message,
      masterUUID,
      activeMasterUUID,
      roles,
      status,
      uri,
      subsections = [],
      match: { url },
    } = this.props;

    const isMaster = instanceUUID === masterUUID;
    const isActiveMaster = instanceUUID === activeMasterUUID;
    const masterState = isActiveMaster ? 'active master' : isMaster ? 'master' : null;

    return (
      <div className={'app-content tr-card-margin'}>
        <PageSectionHead
          title={
            <React.Fragment>
              <HealthIndicator
                className={styles.indicator}
                size="l"
                state={status === 'healthy' ? 'good' : 'bad'}
              />
              {alias} – {uri}{masterState && ` – ${masterState}`}
            </React.Fragment>
          }
        >
          <div className={styles.headerSecondRow}>
            <span title="Roles">{roles}</span>
            {!!message && <span className={styles.headerError}>{message}</span>}
          </div>
        </PageSectionHead>
        <div className={styles.layout}>
          <SubNavMenu className={styles.menu}>
            {subsections.map(section => (
              <SubNavMenu.Item to={`${url}/${section}`}>{section}</SubNavMenu.Item>
            ))}
          </SubNavMenu>
          <div className={styles.sectionContent}>
            <Switch>
              {subsections.map(section => (
                <Route
                  path={`${url}/${section}`}
                  render={() => <ClusterInstanceSection sectionName={section} />}
                />
              ))}
              <Route render={() => (<Redirect to={`${url}/${subsections[0]}`} />)} />
            </Switch>
          </div>
        </div>
      </div>
    );
  }
}

export default ClusterConfig;
