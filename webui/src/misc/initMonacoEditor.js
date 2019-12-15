import * as monaco from 'monaco-editor/esm/vs/editor/edcore.main';
import themeData from 'monaco-themes/themes/Slush and Poppies.json';
import 'monaco-editor/esm/vs/basic-languages/javascript/javascript.contribution';
import 'monaco-editor/esm/vs/basic-languages/yaml/yaml.contribution';
import 'monaco-editor/esm/vs/basic-languages/lua/lua.contribution';
import 'monaco-editor/esm/vs/basic-languages/html/html.contribution';

monaco.languages.registerHoverProvider('yaml', {
  provideHover: function (model, position) {
    if (!this.validationError) {
      return null;
    }

    const {
      endColumn,
      endLineNumber,
      message,
      startColumn,
      startLineNumber
    } = this.validationError;

    return {
      range: new monaco.Range(startLineNumber, startColumn, endLineNumber, endColumn),
      contents: [{ value: message }]
    }
  }
});

themeData.colors['editor.background'] = '#FFF';
themeData.colors['editor.selectionBackground'] = '#BFBFFF';
themeData.colors['editor.lineHighlightBackground'] = '#00000015';

const DEFAULT_THEME_NAME = 'DEFAULT-THEME-NAME';//underscores are not allowed in theme names

monaco.editor.defineTheme(DEFAULT_THEME_NAME, themeData);
monaco.editor.setTheme(DEFAULT_THEME_NAME);

export default monaco;
