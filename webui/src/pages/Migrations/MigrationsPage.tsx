import React from 'react';
import { core } from '@tarantool.io/frontend-core';

import { PageLayout } from 'src/components/PageLayout';
import { migrations } from 'src/models';

import { Migrations } from './components/Migrations';

const { AppTitle } = core.components;
const { MigrationsGate } = migrations;

export const MigrationsPage = () => {
  return (
    <PageLayout heading="Migrations">
      <AppTitle title="Migrations" />
      <MigrationsGate />
      <Migrations />
    </PageLayout>
  );
};
