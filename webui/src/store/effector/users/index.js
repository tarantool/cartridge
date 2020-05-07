// @flow
import init from './init'
import createState from './state'

export const createUsersApi = () => {
  const state = createState()
  init(state)
  return state
}

export default createUsersApi();
