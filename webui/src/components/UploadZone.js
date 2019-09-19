// @flow
import React, { useState } from 'react'
import styled from 'react-emotion'
import { useDropzone } from 'react-dropzone';
import { IconAttach, IconBox } from '@tarantool.io/ui-kit';

const UploadTitle = styled.p`
  font-size: 16px;
  line-height: 24px;
  font-weight: 600;
  font-family: Open Sans;
  margin: 16px 0;
  letter-spacing: 0.32px;
  color: #000;
`

const DropzoneContainer = styled.div`
  margin-bottom: 16px;
`

const UploadNotice = styled.span`
  font-family: Open Sans;
  font-size: 14px;
  font-weight: normal;
  font-style: normal;
  font-stretch: normal;
  line-height: 1.57;
  letter-spacing: 0.28px;
  color: #000000;
`

const UploadableFiles = styled.div`
  display: block;
  margin-bottom: 16px;
`
const UploadableFile = styled.div`
  
`

const FileName = styled.span`
  display: inline-block;
  margin-left 6px;
`

const defaultNotice = `Support for a single or bulk upload`

const getColor = props => {
  if (props.isDragAccept) {
    return '#f5222d';
  }
  return '#d9d9d9';
}

const Container = styled.div`
  cursor: pointer;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24px;
  border-width: 2px;
  border-radius: 2px;
  border-color: ${props => getColor(props)};
  border-style: dashed;
  background-color: #fafafa;
  color: #bdbdbd;
  outline: none;
  transition: border .24s ease-in-out;
`;


type UploadProps = {
  accept?: string,
  handler?: Function,
  name: string,
  multiple?: boolean,
  className?: string,
  label?: string
}

export default function UploadZone(
  {
    accept = '',
    handler,
    name,
    multiple,
    className,
    label
  }: UploadProps
) {
  const [selectedFiles, setSelectedFiles] = useState([]);

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

  const { ref, ...rootProps } = getRootProps({
    isDragAccept
  })

  return (
    <div className={className || ''} ref={ref}>
      <DropzoneContainer>
        <Container
          {...rootProps}
        >
          <input {...getInputProps()} name={name}/>
          <IconBox/>
          <UploadTitle>Click or drag file to this area to upload</UploadTitle>
          <UploadNotice>
            {label ? label : defaultNotice}
          </UploadNotice>
        </Container>
      </DropzoneContainer>
      {selectedFiles.length > 0 && <UploadableFiles>
        {selectedFiles.map(x => {
          return <UploadableFile><IconAttach/><FileName>{x.path}</FileName></UploadableFile>
        })}
      </UploadableFiles>}
    </div>
  );
}
