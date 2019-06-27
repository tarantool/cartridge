// @flow
import { connect } from 'react-redux';
import { pageDidMount, resetPageState } from 'src/store/actions/clusterInstancePage.actions';
import ClusterInstance from './ClusterInstance';
import isEqual from 'lodash/isEqual';
import { defaultMemoize, createSelectorCreator } from 'reselect';

const getSectionsNames = state => Object.keys(state.clusterInstancePage.boxinfo || {});

const selectSectionsNames = createSelectorCreator(
  defaultMemoize,
  isEqual
)(
  getSectionsNames,
  sectionsNames => sectionsNames
)

const mapStateToProps = (state, props) => {
  const {
    alias,
    labels,
    message,
    masterUUID,
    activeMasterUUID,
    roles = [],
    status,
    uri,
  } = state.clusterInstancePage;

  return {
    alias,
    labels,
    message,
    masterUUID,
    activeMasterUUID,
    roles: roles.join(', '),
    status,
    uri,
    subsections: selectSectionsNames(state),
    instanceUUID: props.match.params.instanceUUID,
  };
};

const mapDispatchToProps = {
  pageDidMount,
  resetPageState,
};

export default connect(mapStateToProps, mapDispatchToProps)(ClusterInstance);
