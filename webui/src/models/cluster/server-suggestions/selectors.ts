import type { GetCompressionCluster, GetCompressionClusterCompressionCompressionInfo } from './types';

export const clusterCompressionInfo = (
  data: GetCompressionCluster
): GetCompressionClusterCompressionCompressionInfo => {
  return data?.cluster?.cluster_compression.compression_info ?? [];
};
