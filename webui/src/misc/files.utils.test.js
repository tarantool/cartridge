// @flow
import {
  validateFileNameExtension,
  isDescendant
} from './files.utils';

describe('isDescendant', () => {
  it('identifies descendant', () => {
    expect(isDescendant('folder/file.txt', 'folder')).toEqual(true);
    expect(isDescendant('root/parent/child/', 'root/parent')).toEqual(true);
    expect(isDescendant('root/parent/child/file.txt', 'root/parent')).toEqual(true);
    expect(isDescendant('/file.txt', '')).toEqual(true);
  });

  it('substring is NOT a descendant!', () => {
    expect(isDescendant('SOME/PREFIX-and-name.txt', 'SOME/PREFIX')).toEqual(false);
  });

  it('identifies descendant (it\'s any path) of an empty path', () => {
    expect(isDescendant('/folder/file.txt', '')).toEqual(true);
  });

  it('doesn\'t give a false positive result', () => {
    expect(isDescendant('folder1/file.txt', 'folder2/')).toEqual(false);
    expect(isDescendant('', '/')).toEqual(false);
  });

  it('a path is not it\'s own descendant', () => {
    expect(isDescendant('', '')).toEqual(false);

    const somePath = 'path/to/a/file';
    expect(isDescendant(somePath, somePath)).toEqual(false);
  });
});


describe('validateFileNameExtension', () => {
  const itAllowsExtension = (ext: string) => it(`allows .${ext}`, () => {
    expect(validateFileNameExtension(`a.${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`1.${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`..${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`-.${ext}`)).toEqual(true);
    expect(validateFileNameExtension(` .${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`long_file-name.${ext}`)).toEqual(true);
  });
  itAllowsExtension('lua');
  itAllowsExtension('yml');

  it('allows empty names (with extension)', () => {
    expect(validateFileNameExtension('.lua')).toEqual(true);
    expect(validateFileNameExtension('.yml')).toEqual(true);
  });

  it('tests only last extension', () => {
    expect(validateFileNameExtension('name.yml.sh')).toEqual(false);
    expect(validateFileNameExtension('name.sh.yml')).toEqual(true);
    expect(validateFileNameExtension('.sh.lua.lua.sh')).toEqual(false);
    expect(validateFileNameExtension('.yml.yml')).toEqual(true);
  });

  it('forbid names without extensions', () => {
    expect(validateFileNameExtension('name')).toEqual(false);
    expect(validateFileNameExtension('README')).toEqual(false);
  });

  it('forbid other extensions', () => {
    [
      'yaml',
      'sh',
      'zip',
      'exe',
      'dmg',
      'pkg',
      'git',
      'js',
      'py',
      'txt',
      'jpg',
      'png',
      'svg',
      'some-other-ext'
    ].forEach(
      ext => expect([ext, '=>', validateFileNameExtension(`name.${ext}`)]).toEqual([ext, '=>', false])
    );
  });
});
