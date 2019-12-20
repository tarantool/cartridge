import {
  validateFileNameExtension,
} from './files.utils';

describe('validateFileNameExtension', () => {
  const itAllowsExtention = (ext) => it(`allows .${ext}`, () => {
    expect(validateFileNameExtension(`a.${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`1.${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`..${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`-.${ext}`)).toEqual(true);
    expect(validateFileNameExtension(` .${ext}`)).toEqual(true);
    expect(validateFileNameExtension(`long_file-name.${ext}`)).toEqual(true);
  });
  itAllowsExtention('lua');
  itAllowsExtention('yml');

  it('allows empty names (with extention)', () => {
    expect(validateFileNameExtension('.lua')).toEqual(true);
    expect(validateFileNameExtension('.yml')).toEqual(true);
  });

  it('tests only last extention', () => {
    expect(validateFileNameExtension('name.yml.sh')).toEqual(false);
    expect(validateFileNameExtension('name.sh.yml')).toEqual(true);
    expect(validateFileNameExtension('.sh.lua.lua.sh')).toEqual(false);
    expect(validateFileNameExtension('.yml.yml')).toEqual(true);
  });

  it('forbid names without extentions', () => {
    expect(validateFileNameExtension('name')).toEqual(false);
    expect(validateFileNameExtension('README')).toEqual(false);
  });

  it('forbid other extentions', () => {
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