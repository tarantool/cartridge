import type { EditReplicasetInput } from 'src/generated/graphql-typing-ts';

export interface ClusterServeConfigureGateProps {
  uri: string;
}

export interface JoinReplicasetProps {
  uri: string;
  uuid: string;
}

export type CreateReplicasetProps = Omit<EditReplicasetInput, 'uuid'>;
