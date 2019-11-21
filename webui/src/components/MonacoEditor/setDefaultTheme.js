import * as monaco from 'monaco-editor/esm/vs/editor/edcore.main.js';
import themeData from 'monaco-themes/themes/Slush and Poppies.json';

themeData.colors['editor.background'] = '#FFF';
themeData.colors['editor.selectionBackground'] = '#BFBFFF';
themeData.colors['editor.lineHighlightBackground'] = '#00000015';

const DEFAULT_THEME_NAME = 'DEFAULT-THEME-NAME';//underscores are not allowed in theme names

monaco.editor.defineTheme(DEFAULT_THEME_NAME, themeData);
monaco.editor.setTheme(DEFAULT_THEME_NAME);
