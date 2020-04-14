import init from './init'
import createState from './state'

export const createConfigApi = () => {
  const state = createState()
  init(state)
  return state
}
