/* eslint-disable @typescript-eslint/ban-ts-comment */
import { FormikProps, withFormik } from 'formik';
import * as yup from 'yup';

import { app } from 'src/models';

export interface JoinReplicasetProps {
  onClose: () => void;
}

// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface JoinReplicasetValues {}

const { tryCatchWithNotify } = app;

const validationSchema = yup.object<JoinReplicasetValues>({}).required();

export type JoinReplicasetFormikProps = FormikProps<JoinReplicasetValues> & JoinReplicasetProps;

export const withJoinReplicasetForm = withFormik<JoinReplicasetProps, JoinReplicasetValues>({
  displayName: 'JoinReplicasetForm',
  validationSchema,
  handleSubmit: () => {
    tryCatchWithNotify(() => {
      //   const casted = validationSchema.cast(values, {
      //     abortEarly: true,
      //     stripUnknown: true,
      //   });
    });
  },
});
