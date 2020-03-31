// @flow

import { createConfigApi } from './configUpload'
import nock from 'nock'
import axios from 'axios'

axios.defaults.adapter = require('axios/lib/adapters/http')

const fullFiles : Array<File> = [new File([''], 'tt.yml')]
const emptyFiles : Array<File> = []

const scope = nock('localhost')
  .get('/repos/atom/atom/license')
  .reply(200, {
    license: {
      key: 'mit',
      name: 'MIT License',
      spdx_id: 'MIT',
      url: 'https://api.github.com/licenses/mit',
      node_id: 'MDc6TGljZW5zZTEz',
    },
  })

describe('config upload', () => {
  it('button availability', () => {
    const { $configForm, dropFiles, uploadClick } = createConfigApi()

    let state = $configForm.getState()
    expect(state.files).toHaveLength(0)

    dropFiles(emptyFiles)
    state = $configForm.getState()
    expect(state.files).toHaveLength(0)

    dropFiles(fullFiles)
    state = $configForm.getState()
    expect(state.files).toHaveLength(1)

    dropFiles(emptyFiles)

    state = $configForm.getState()
    expect(state.files).toHaveLength(0)
  })
})
