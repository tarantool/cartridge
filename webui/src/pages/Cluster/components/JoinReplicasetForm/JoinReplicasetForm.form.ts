/* eslint-disable @typescript-eslint/ban-ts-comment */
import { FormikProps, withFormik } from 'formik';

import { app } from 'src/models';

export interface JoinReplicasetValues {
  replicasetUuid: string;
}
export interface JoinReplicasetProps {
  pending: boolean;
  onClose: () => void;
  onSubmit: (values: JoinReplicasetValues) => void;
}

const { tryCatchWithNotify, yup } = app;

const validationSchema = yup
  .object<JoinReplicasetValues>({
    replicasetUuid: yup.string().required(),
  })
  .required();

export type JoinReplicasetFormikProps = FormikProps<JoinReplicasetValues> & JoinReplicasetProps;

export const withJoinReplicasetForm = withFormik<JoinReplicasetProps, JoinReplicasetValues>({
  displayName: 'JoinReplicasetForm',
  validationSchema,
  validateOnMount: true,
  handleSubmit: (values, { props: { onSubmit } }) => {
    tryCatchWithNotify(() => {
      const casted = validationSchema.cast(values, {
        abortEarly: true,
        stripUnknown: true,
      });

      onSubmit(casted);
    });
  },
});
