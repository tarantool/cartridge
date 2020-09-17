// @flow
import React, { useState } from 'react';
import styled from 'react-emotion';
import { css, cx } from 'emotion';
import { useDropzone } from 'react-dropzone';
import { IconBox, Text, colors } from '@tarantool.io/ui-kit';

const styles = {
  wrap: css`
    display: flex;
  `,
  icon: css`
    width: 48px;
    height: 48px;
    margin-bottom: 16px;
    fill: ${colors.intentBase};
  `,
  notice: css`
    margin-top: 16px;
    color: ${colors.dark65};
  `
};

const getColor = props => {
  if (props.isDragAccept) {
    return '#f5222d';
  }
  return '#d9d9d9';
}

const Container = styled.div`
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 20px;
  border-width: 1px;
  border-radius: 4px;
  border-color: ${props => getColor(props)};
  border-style: dashed;
  background-color: ${colors.intentBaseActive};
  transition: border .24s ease-in-out;
  outline: none;
  cursor: pointer;
`;


type UploadZoneProps = {
  accept?: string,
  handler?: Function,
  name: string,
  multiple?: boolean,
  className?: string,
  label?: string,
  files?: Array<File>
}

export default function UploadZone(
  {
    accept = '',
    handler,
    name,
    multiple,
    className,
    label,
    files
  }: UploadZoneProps
) {
  const [selectedFiles, setSelectedFiles] = useState<Array<File>>([]);

  const {
    getRootProps,
    getInputProps,
    isDragAccept
  } = useDropzone({
    accept,
    multiple,
    onDrop: (files, ...args) => {
      handler && handler(files, ...args)
      setSelectedFiles(files)
    }
  });

  const refFiles = files || selectedFiles

  const { ref, ...rootProps } = getRootProps({
    isDragAccept
  })

  return (
    <div className={cx(styles.wrap, className)} ref={ref}>
      <Container
        {...rootProps}
      >
        <input {...getInputProps()} name={name}/>
        <IconBox className={styles.icon} />
        <Text variant='h3' tag='span'>
            Click or drag file to this area to upload
        </Text>
        {!!label && <Text className={styles.notice}>{label}</Text>}
      </Container>
      {refFiles.length > 0 && console.log(refFiles)}
    </div>
  );
}
