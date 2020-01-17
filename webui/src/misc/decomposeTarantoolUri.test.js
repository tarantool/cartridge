import { validateTarantoolUri, decomposeTarantoolUri } from './decomposeTarantoolUri.js'

test('decompose tarantool uri test', () => {
  const test = 'https://tarantool.io'
  const validUri = 'admin:npngatmwsf@try-cartridge.tarantool.io:10300'
  expect(validateTarantoolUri(test)).toBe(false)
  expect(validateTarantoolUri('')).toBe(false)
  expect(validateTarantoolUri(null)).toBe(false)
  expect(validateTarantoolUri(validUri)).toBe(true)
  const { user, password, host, port } = decomposeTarantoolUri(validUri)
  expect(user).toBe('admin')
  expect(password).toBe('npngatmwsf')
  expect(host).toBe('try-cartridge.tarantool.io')
  expect(port).toBe('10300')
})
