import '../../init';

import { allSettled, fork } from 'effector';
import { core } from '@tarantool.io/frontend-core';

import { domain } from '../../app';
import { queryClusterFx, queryServerListFx } from '../server-list';
import {
  $failoverModal,
  changeFailoverEvent,
  changeFailoverFx,
  failoverModalCloseEvent,
  failoverModalOpenEvent,
  getFailoverFx,
} from '.';

let getFailoverFxUse;
let changeFailoverFxUse;
let queryServerListFxUse;
let queryClusterFxUse;

const getFailoverFxMock = () =>
  Promise.resolve({
    cluster: {
      failover_params: {
        failover_timeout: 10,
        fencing_enabled: true,
        fencing_timeout: 10,
        fencing_pause: 10,
        mode: 'disabled',
      },
    },
  });

describe('models.cluster.failover', () => {
  beforeEach(() => {
    getFailoverFxUse = getFailoverFx.use.getCurrent();
    changeFailoverFxUse = changeFailoverFx.use.getCurrent();
    queryServerListFxUse = queryServerListFx.use.getCurrent();
    queryClusterFxUse = queryClusterFx.use.getCurrent();

    queryServerListFx.use(() => Promise.reject(new Error('queryServerListFx.error')));
    queryClusterFx.use(() => Promise.reject(new Error('queryClusterFx.error')));
  });

  afterEach(() => {
    getFailoverFx.use(getFailoverFxUse);
    changeFailoverFx.use(changeFailoverFxUse);
    queryServerListFx.use(queryServerListFxUse);
    queryClusterFx.use(queryClusterFxUse);
  });

  it('getFailoverFx/success', async () => {
    const getFailoverFxResult = jest.fn(getFailoverFxMock);
    getFailoverFx.use(getFailoverFxResult);

    const scope = fork(domain, {});
    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: false }));

    await allSettled(failoverModalOpenEvent, { scope });
    expect(getFailoverFxResult).toBeCalledTimes(1);
    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: true }));

    await allSettled(failoverModalCloseEvent, { scope });
    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: false }));
  });

  it('getFailoverFx/error', async () => {
    const spyNotify = jest.spyOn(core, 'notify');
    const getFailoverFxResult = jest.fn(() => Promise.reject(new Error('getFailoverFx.error')));
    getFailoverFx.use(getFailoverFxResult);

    const scope = fork(domain, {});
    await allSettled(failoverModalOpenEvent, { scope });

    expect(getFailoverFxResult).toBeCalledTimes(1);
    expect(spyNotify).toBeCalledWith(expect.objectContaining({ message: 'getFailoverFx.error' }));
    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: false }));
  });

  it('changeFailoverFx/success', async () => {
    getFailoverFx.use(getFailoverFxMock);

    const changeFailoverFxResult = jest.fn(({ mode }: { mode: string }) =>
      Promise.resolve({
        cluster: {
          failover_params: { mode },
        },
      })
    );

    changeFailoverFx.use(changeFailoverFxResult);

    const scope = fork(domain, {});
    await allSettled(failoverModalOpenEvent, { scope });
    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: true }));

    await allSettled(changeFailoverEvent, {
      scope,
      params: {
        mode: 'mode1',
      },
    });

    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: false }));
  });

  it('changeFailoverFx/error', async () => {
    getFailoverFx.use(getFailoverFxMock);

    const changeFailoverFxResult = jest.fn(() => Promise.reject(new Error('changeFailoverFx.error')));
    changeFailoverFx.use(changeFailoverFxResult);

    const scope = fork(domain, {});
    await allSettled(failoverModalOpenEvent, { scope });
    expect(scope.getState($failoverModal)).toEqual(expect.objectContaining({ visible: true }));

    await allSettled(changeFailoverEvent, {
      scope,
      params: {
        mode: 'disabled',
      },
    });

    expect(scope.getState($failoverModal)).toEqual(
      expect.objectContaining({ visible: true, error: 'changeFailoverFx.error' })
    );
  });
});
