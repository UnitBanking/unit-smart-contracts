const config = {
  semi: false,
  singleQuote: true,
  printWidth: 120,
  bracketSpacing: true,
  plugins: [require.resolve('prettier-plugin-solidity')],
  overrides: [
    {
      files: '*.sol',
      options: {
        tabWidth: 4
      }
    }
  ]
};

module.exports = config;