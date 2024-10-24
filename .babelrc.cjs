const path = require('path');
const jsConfig = require('./jsconfig.json');

module.exports = {
  include: [/src/, /node_modules/],
  presets: ['@babel/preset-env'],
  targets: {
    node: "20.16"
  },
  plugins: [
    ['@babel/plugin-syntax-import-attributes',
      {
        deprecatedAssertSyntax: true,
      },
    ],
    [
      'module-resolver',
      {
        root: [path.resolve(jsConfig.compilerOptions.baseUrl)],
      },
    ]
  ],
};
