import type { GetClusterCompressionQuery } from 'src/generated/graphql-typing-ts';
import type { Maybe } from 'src/models';

export type GetCompressionCluster = Maybe<GetClusterCompressionQuery>;
export type GetCompressionClusterCompression = NonNullable<
  Required<NonNullable<GetCompressionCluster>>['cluster']
>['cluster_compression'];
export type GetCompressionClusterCompressionCompressionInfo =
  NonNullable<GetCompressionClusterCompression>['compression_info'];

export interface CompressionSuggestion {
  type: 'compression';
  meta: {
    instanceId: string;
    spaceName: string;
    fields: Array<{ name: string; compressionPercentage: number }>;
  };
}

export type Suggestion = CompressionSuggestion;
