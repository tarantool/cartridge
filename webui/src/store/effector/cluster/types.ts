import type { FailoverApi, Issue, Replicaset, Server, ServerStat, Suggestions } from 'src/generated/graphql-typing-ts';
import type { RequestStatusType } from 'src/store/commonTypes';

export interface ServerStatWithUUID {
  uuid: string;
  uri: string;
  statistics: ServerStat;
}

export interface ClusterPageState {
  issues: Issue[];
  replicasetFilter: string;
  modalReplicasetFilter: string;
  pageMount: boolean;
  pageDataRequestStatus: RequestStatusType;
  refreshListsRequestStatus: RequestStatusType;
  selectedServerUri: string | undefined;
  selectedReplicasetUuid: string;
  serverList: Server[] | undefined;
  replicasetList: Replicaset[] | undefined;
  //
  failoverMode: string | undefined;
  failoverDataRequestStatus: RequestStatusType;
  failover_params: Pick<FailoverApi, 'mode' | 'tarantool_params' | 'state_provider'>;
  //
  serverStat: ServerStatWithUUID[] | undefined;
  bootstrapVshardRequestStatus: RequestStatusType;
  // bootstrapVshardResponse: null,
  probeServerError: Error | undefined;
  probeServerRequestStatus: RequestStatusType;
  // probeServerResponse: null,
  joinServerRequestStatus: RequestStatusType;
  // joinServerResponse: null,
  createReplicasetRequestStatus: RequestStatusType;
  // createReplicasetResponse: null,
  expelServerRequestStatus: RequestStatusType;
  // expelServerResponse: null,
  editReplicasetRequestStatus: RequestStatusType;
  // editReplicasetResponse: null,
  uploadConfigRequestStatus: RequestStatusType;
  applyTestConfigRequestStatus: RequestStatusType;
  // applyTestConfigResponse: null,
  changeFailoverRequestStatus: RequestStatusType;
}

export interface ClusterState extends ClusterPageState {
  suggestions?: Suggestions;
}
