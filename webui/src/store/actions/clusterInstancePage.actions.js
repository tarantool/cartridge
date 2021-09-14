import { CLUSTER_INSTANCE_DID_MOUNT, CLUSTER_INSTANCE_STATE_RESET } from 'src/store/actionTypes';
import { getActionCreator, getPageMountActionCreator } from 'src/store/commonRequest';

export const pageDidMount = getPageMountActionCreator(CLUSTER_INSTANCE_DID_MOUNT);

export const resetPageState = getActionCreator(CLUSTER_INSTANCE_STATE_RESET);
