import * as React from 'react'
import styled, { css, cx } from 'react-emotion'

export const FieldGroup = styled.div`
  padding-bottom: 24px;
  position: relative;
`

export const FieldLabel = styled.label`
  margin-bottom: 8px;
  font-size: 14px;
  line-height: 24px;
  font-weight: 600;
  font-family: Open Sans;
  overflow: hidden;
  display: block;
  color: #000;
  text-transform: capitalize;
  
`

export const FieldRequired = styled.span`
  color: #f5222d;
`

export const FieldError = styled.div`
  position: absolute;
  bottom: 4px;
  font-size: 12px;
  color: #f5222d;
`

export const FieldInput = styled.div`
   height: 32px;
`

export const FormContainer = styled.div`
  padding: 0 16px;
  
`

export const FieldConstructor = ({ label, input, required, error }) =>
  <FieldGroup>
    <FieldLabel>{label}{required && <FieldRequired>*</FieldRequired>}:</FieldLabel>
    <FieldInput>
      {input}
    </FieldInput>
    {error && <FieldError>{error}</FieldError>}
  </FieldGroup>
