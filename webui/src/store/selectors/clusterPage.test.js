import { filterReplicasetList, getFilterData, getReplicasetCounts, getServerCounts } from './clusterPage';

const brokenState = { clusterPage: {} };

const emptyState = {
  clusterPage: {
    replicasetList: [],
    serverList: [],
  },
};

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
        message: 'Instance is not in config',
      },
      {
        replicaset: null,
        uri: 'localhost:3304',
        alias: 'srv-4',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config',
      },
      {
        replicaset: null,
        uri: 'localhost:3303',
        alias: 'srv-3',
        status: 'unconfigured',
        uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        message: '',
      },
      {
        replicaset: null,
        uri: 'localhost:3305',
        alias: 'srv-5',
        status: 'unconfigured',
        uuid: 'a6eeb258-7d86-4ff2-8621-cb6c8a96a37f',
        message: '',
      },
      {
        replicaset: null,
        uri: 'localhost:3301',
        alias: 'srv-1',
        status: 'unconfigured',
        uuid: 'd97e299e-19d2-4dfc-ac21-0985a1ba2668',
        message: '',
      },
    ],
  },
};

const unhealthyState = {
  clusterPage: {
    replicasetList: [
      {
        servers: [],
        active_master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        },
        vshard_group: null,
        weight: null,
        status: 'unhealthy',
        master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        },
        uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        roles: ['myrole-dependency', 'myrole'],
      },
    ],
    serverList: [
      {
        replicaset: null,
        uri: 'localhost:3302',
        alias: 'srv-2',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config',
      },
      {
        replicaset: null,
        uri: 'localhost:3304',
        alias: 'srv-4',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config',
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        },
        uri: 'localhost:3303',
        alias: 'srv-3',
        status: 'healthy',
        uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        message: '',
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        },
        uri: 'localhost:3305',
        alias: 'srv-5',
        status: 'unreachable',
        uuid: 'a6eeb258-7d86-4ff2-8621-cb6c8a96a37f',
        message: '',
      },
      {
        replicaset: {
          uuid: '2d5b82e6-3f4c-489a-b130-d4799196f3e8',
        },
        uri: 'localhost:3301',
        alias: 'srv-1',
        status: 'healthy',
        uuid: 'd97e299e-19d2-4dfc-ac21-0985a1ba2668',
        message: '',
      },
    ],
  },
};

const state = {
  clusterPage: {
    replicasetList: [
      {
        servers: [],
        active_master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        },
        vshard_group: null,
        weight: null,
        status: 'healthy',
        master: {
          uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        },
        uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        roles: ['myrole-dependency', 'myrole'],
      },
    ],
    serverList: [
      {
        replicaset: null,
        uri: 'localhost:3302',
        alias: 'srv-2',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config',
      },
      {
        replicaset: null,
        uri: 'localhost:3304',
        alias: 'srv-4',
        status: 'unconfigured',
        uuid: '',
        message: 'Instance is not in config',
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        },
        uri: 'localhost:3303',
        alias: 'srv-3',
        status: 'healthy',
        uuid: '3be3c0c5-6e15-46bb-8546-ff6c4a664012',
        message: '',
      },
      {
        replicaset: {
          uuid: '4733fbdb-d093-4f10-9c63-a834250a23aa',
        },
        uri: 'localhost:3305',
        alias: 'srv-5',
        status: 'healthy',
        uuid: 'a6eeb258-7d86-4ff2-8621-cb6c8a96a37f',
        message: '',
      },
      {
        replicaset: {
          uuid: '2d5b82e6-3f4c-489a-b130-d4799196f3e8',
        },
        uri: 'localhost:3301',
        alias: 'srv-1',
        status: 'healthy',
        uuid: 'd97e299e-19d2-4dfc-ac21-0985a1ba2668',
        message: '',
      },
    ],
  },
};

const stubReplicaSet = (() => {
  let uniqUuid = 0;
  return (updateShape) => ({
    servers: [],
    active_master: {
      uuid: 'abc',
    },
    vshard_group: null,
    weight: null,
    status: 'healthy',
    master: {
      uuid: 'abc',
    },
    uuid: `uuid-${uniqUuid++}`,
    roles: [],
    ...updateShape,
  });
})();

const stubState = (replicasetList) => ({
  clusterPage: {
    replicasetList,
    serverList: [
      //...
    ],
  },
});

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

describe('filter (search) replicasets', () => {
  it('unknown prefix are treated as simple value', () => {
    const filterQuery = 'unknown-prefix:value';
    expect(getFilterData(filterQuery).tokensByPrefix).toEqual({
      all: [filterQuery],
    });
  });

  it('modifiers are parsed correctly', () => {
    const filterQuery = 'alias:exactly-this alias*:this-substring alias!:not-this';
    expect(getFilterData(filterQuery).tokensByPrefix).toEqual({
      all: [],
      alias: [
        {
          asSubstring: false,
          not: false,
          value: 'exactly-this',
        },
        {
          asSubstring: true,
          not: false,
          value: 'this-substring',
        },
        {
          asSubstring: false,
          not: true,
          value: 'not-this',
        },
      ],
    });
  });

  it('reolicaSet prefixes (uuid, role, alias, status) are detected', () => {
    const filterQuery = 'uuid:some-uuid role:some-role alias:some-alias status:healthy';
    expect(getFilterData(filterQuery).tokensByPrefix).toEqual({
      all: [],
      uuid: [
        {
          asSubstring: false,
          not: false,
          value: 'some-uuid',
        },
      ],
      roles: [
        {
          asSubstring: false,
          not: false,
          value: 'some-role',
        },
      ],
      alias: [
        {
          asSubstring: false,
          not: false,
          value: 'some-alias',
        },
      ],
      status: [
        {
          asSubstring: false,
          not: false,
          value: 'healthy',
        },
      ],
    });
  });

  it('correctly finds status:healthy', () => {
    const filterQuery = 'status:healthy';
    const filteredList = filterReplicasetList(state, filterQuery);
    expect(filteredList.length).toEqual(state.clusterPage.replicasetList.length);
  });

  it('return [] if nothing can be found', () => {
    expect(filterReplicasetList(unhealthyState, 'status:healthy')).toEqual([]);
    expect(filterReplicasetList(brokenState, 'abrakadabra')).toEqual([]);
  });
});

describe('Correctly finds (filters) replicaset by ...', () => {
  it('by "uuid:..."', () => {
    const replicaToBeFound = stubReplicaSet({ uuid: 'uuid-to-be-found' });
    const replicaOther = stubReplicaSet({ uuid: 'uuid-other' });
    const state = stubState([replicaToBeFound, replicaOther]);

    const result = filterReplicasetList(state, 'uuid-to-be-found');
    expect(result.length).toEqual(1);
    expect(result[0].uuid).toEqual(replicaToBeFound.uuid);
  });

  it('by "role:..."', () => {
    const replicaToBeFound = stubReplicaSet({
      roles: ['myrole-dependency', 'myrole'],
    });
    const replicaOther = stubReplicaSet({
      roles: ['some-other-role', 'myrole'],
    });
    const state = stubState([replicaToBeFound, replicaOther]);

    const result = filterReplicasetList(state, 'role:myrole-dependency');
    expect(result.length).toEqual(1);
    expect(result[0].uuid).toEqual(replicaToBeFound.uuid);
  });

  it('by "alias:..."', () => {
    const replicaToBeFound = stubReplicaSet({ alias: 'svr-1' });
    const replicaOther = stubReplicaSet({ alias: 'srv-5' });
    const state = stubState([replicaOther, replicaToBeFound]);

    const result = filterReplicasetList(state, 'alias:svr-1');
    expect(result.length).toEqual(1);
    expect(result[0].uuid).toEqual(replicaToBeFound.uuid);
  });

  describe('by "status:..."', () => {
    const replicaHealthy = stubReplicaSet({ status: 'healthy' });
    const replicaUnhealthy = stubReplicaSet({ status: 'unhealthy' });
    const state = stubState([replicaUnhealthy, replicaHealthy]);

    it('status:healthy', () => {
      const result = filterReplicasetList(state, 'status:healthy');
      expect(result.length).toEqual(1);
      expect(result[0].uuid).toEqual(replicaHealthy.uuid);
    });

    it('status:unhealthy', () => {
      const result = filterReplicasetList(state, 'status:unhealthy');
      expect(result.length).toEqual(1);
      expect(result[0].uuid).toEqual(replicaUnhealthy.uuid);
    });
  });
});
