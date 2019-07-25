import {
  getServerCounts,
  getReplicasetCounts
} from './clusterPage';

const brokenState = { clusterPage: {} };

const emptyState = {
  clusterPage: {
    replicasetList: [],
    serverList: []
  },
}

const unconfiguredState = {
  clusterPage: {
    replicasetList: [],
    serverList: [
      {
        replicaset: null,
        uri: 'localhost:3302',
        alias: 'srv-2',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config'
      },
      {
        replicaset: null,
        uri: 'localhost:3304',
        alias: 'srv-4',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config'
      },
      {
        replicaset: null,
        uri: 'localhost:3303',
        alias: 'srv-3',
        status: 'unconfigured',
        uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        message: ''
      },
      {
        replicaset: null,
        uri: 'localhost:3305',
        alias: 'srv-5',
        status: 'unconfigured',
        uuid: 'a6eeb258-7d86-4ff2-8621-cb6c8a96a37f',
        message: ''
      },
      {
        replicaset: null,
        uri: 'localhost:3301',
        alias: 'srv-1',
        status: 'unconfigured',
        uuid: 'd97e299e-19d2-4dfc-ac21-0985a1ba2668',
        message: ''
      }
    ],
  },
}

const unhealthyState = {
  clusterPage: {
    replicasetList: [
      {
        servers: [],
        active_master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012'
        },
        vshard_group: null,
        weight: null,
        status: 'unhealthy',
        master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012'
        },
        uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        roles: [
          'myrole-dependency',
          'myrole'
        ]
      }
    ],
    serverList: [
      {
        replicaset: null,
        uri: 'localhost:3302',
        alias: 'srv-2',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config'
      },
      {
        replicaset: null,
        uri: 'localhost:3304',
        alias: 'srv-4',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config'
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa'
        },
        uri: 'localhost:3303',
        alias: 'srv-3',
        status: 'healthy',
        uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        message: ''
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa'
        },
        uri: 'localhost:3305',
        alias: 'srv-5',
        status: 'unreachable',
        uuid: 'a6eeb258-7d86-4ff2-8621-cb6c8a96a37f',
        message: ''
      },
      {
        replicaset: {
          uuid: '2d5b82e6-3f4c-489a-b130-d4799196f3e8'
        },
        uri: 'localhost:3301',
        alias: 'srv-1',
        status: 'healthy',
        uuid: 'd97e299e-19d2-4dfc-ac21-0985a1ba2668',
        message: ''
      }
    ],
  },
}

const state = {
  clusterPage: {
    replicasetList: [
      {
        servers: [],
        active_master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012'
        },
        vshard_group: null,
        weight: null,
        status: 'healthy',
        master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012'
        },
        uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        roles: [
          'myrole-dependency',
          'myrole'
        ]
      }
    ],
    serverList: [
      {
        replicaset: null,
        uri: 'localhost:3302',
        alias: 'srv-2',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config'
      },
      {
        replicaset: null,
        uri: 'localhost:3304',
        alias: 'srv-4',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config'
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa'
        },
        uri: 'localhost:3303',
        alias: 'srv-3',
        status: 'healthy',
        uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        message: ''
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa'
        },
        uri: 'localhost:3305',
        alias: 'srv-5',
        status: 'healthy',
        uuid: 'a6eeb258-7d86-4ff2-8621-cb6c8a96a37f',
        message: ''
      },
      {
        replicaset: {
          uuid: '2d5b82e6-3f4c-489a-b130-d4799196f3e8'
        },
        uri: 'localhost:3301',
        alias: 'srv-1',
        status: 'healthy',
        uuid: 'd97e299e-19d2-4dfc-ac21-0985a1ba2668',
        message: ''
      }
    ],
  },
}

describe('getServerCounts', () => {
  it('correctly counts servers', () => {
    expect(getServerCounts(state)).toEqual({ configured: 3, unconfigured: 2, total: 5 });
    expect(getServerCounts(emptyState)).toEqual({ configured: 0, unconfigured: 0, total: 0 });
    expect(getServerCounts(unhealthyState)).toEqual({ configured: 3, unconfigured: 2, total: 5 });
    expect(getServerCounts(unconfiguredState)).toEqual({ configured: 0, unconfigured: 5, total: 5 });
  });

  it('handles empty state', () => {
    expect(getServerCounts(brokenState)).toEqual({ configured: 0, unconfigured: 0, total: 0 });
  });
});

describe('getReplicasetCounts', () => {
  it('correctly counts replicasets', () => {
    expect(getReplicasetCounts(state)).toEqual({ total: 1, unhealthy: 0 });
    expect(getReplicasetCounts(emptyState)).toEqual({ total: 0, unhealthy: 0 });
    expect(getReplicasetCounts(unhealthyState)).toEqual({ total: 1, unhealthy: 1 });
    expect(getReplicasetCounts(unconfiguredState)).toEqual({ total: 0, unhealthy: 0 });
  });

  it('handles empty state', () => {
    expect(getReplicasetCounts(brokenState)).toEqual({ total: 0, unhealthy: 0 });
  });
});
