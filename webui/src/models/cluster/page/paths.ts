import { PROJECT_NAME } from 'src/constants';

const path = (path: string) => `/${PROJECT_NAME}/${path}`;

export const root = () => path('dashboard');

export const serverDetails = ({ uuid }: { uuid: string }) => path(`dashboard/instance/${uuid}`);

export const replicasetConfigure = ({ uuid }: { uuid: string }) => {
  return path(`dashboard?r=${uuid}`);
};

export const serverConfigure = ({ uri }: { uri: string }) => {
  return path(`dashboard?s=${uri}`);
};
