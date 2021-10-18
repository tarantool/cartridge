/* eslint-disable @typescript-eslint/ban-ts-comment */
import { FormikProps, withFormik } from 'formik';
import * as yup from 'yup';

import { app, cluster } from 'src/models';

export interface ProbeServerFormValues {
  uri: string;
}

const { serverProbeEvent } = cluster.serverProbe;
const { tryCatchWithNotify, messages } = app;

const validationSchema = yup
  .object<ProbeServerFormValues>({
    uri: yup.string().required(messages.errors.REQUIRED),
  })
  .required();

export type ProbeServerFormProps = FormikProps<ProbeServerFormValues>;

// eslint-disable-next-line @typescript-eslint/ban-types
export const withProbeServerForm = withFormik<{}, ProbeServerFormValues>({
  displayName: 'ProbeServerForm',
  validationSchema,
  handleSubmit: (values) => {
    tryCatchWithNotify(() => {
      const { uri } = validationSchema.cast(values, {
        abortEarly: true,
        stripUnknown: true,
      });

      serverProbeEvent({ uri });
    });
  },
});
