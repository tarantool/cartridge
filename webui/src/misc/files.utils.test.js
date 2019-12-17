import {
  validateFileNameExtention,
} from './files.utils';

describe('validateFileNameExtention', () => {
  const itAllowsExtention = (ext) => it(`allows .${ext}`, () => {
    expect(validateFileNameExtention(`a.${ext}`)).toEqual(true);
    expect(validateFileNameExtention(`1.${ext}`)).toEqual(true);
    expect(validateFileNameExtention(`..${ext}`)).toEqual(true);
    expect(validateFileNameExtention(`-.${ext}`)).toEqual(true);
    expect(validateFileNameExtention(` .${ext}`)).toEqual(true);
    expect(validateFileNameExtention(`long_file-name.${ext}`)).toEqual(true);
  });
  itAllowsExtention('lua');
  itAllowsExtention('yml');

  it('allows empty names (with extention)', () => {
    expect(validateFileNameExtention('.lua')).toEqual(true);
    expect(validateFileNameExtention('.yml')).toEqual(true);
  });

  it('tests only last extention', () => {
    expect(validateFileNameExtention('name.yml.sh')).toEqual(false);
    expect(validateFileNameExtention('name.sh.yml')).toEqual(true);
    expect(validateFileNameExtention('.sh.lua.lua.sh')).toEqual(false);
    expect(validateFileNameExtention('.yml.yml')).toEqual(true);
  });

  it('forbid names without extentions', () => {
    expect(validateFileNameExtention('name')).toEqual(false);
    expect(validateFileNameExtention('README')).toEqual(false);
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
      ext => expect([ext, '=>', validateFileNameExtention(`name.${ext}`)]).toEqual([ext, '=>', false])
    );
  });
});