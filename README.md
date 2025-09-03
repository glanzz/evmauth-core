# EVMAuth Core

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/evmauth/evmauth-core/test.yml?label=Tests)
![GitHub Repo stars](https://img.shields.io/github/stars/evmauth/evmauth-core)

EVMAuth is an authorization state management system for token-gating, built on top of [ERC-1155] and [ERC-6909] token standards.

There are several variations of EVMAuth for each token standard, combining features like upgrade-ability, role-based access control, account freezing, and token configuration (transferability, price, TTL) with optional token expiry and direct token purchasing via native currency or ERC-20 tokens.

Learn more about how EVMAuth works [here](src/README.md).

## Prerequisites

- [Foundry](https://getfoundry.sh/)
- [Solidity](https://docs.soliditylang.org/en/v0.8.0/installing-solidity.html)

## Setup

1. Clone the repository:

   ```sh
   git clone git@github.com:evmauth/evmauth-core.git
   ```

2. Navigate to the project directory:

   ```sh
   cd evmauth-core
   ```

3. Install the dependencies:

   ```sh
   forge install foundry-rs/forge-std
   forge install OpenZeppelin/openzeppelin-contracts-upgradeable
   forge install OpenZeppelin/openzeppelin-foundry-upgrades
   ```

## Run Tests

To run the tests, use the following command:

```sh
forge test --ffi
```

Use the `--force` flag to recompile the contracts before running the tests:

```sh
forge test --ffi --force
```

To run tests with detailed output, use the `-vv`, `-vvv`, or `-vvvv` flag:

```sh
forge test --ffi -vvv
```

To specify a particular test file, use the `--match-path` option:

```sh
forge test --ffi --match-path test/YourTestFile.t.sol
```

To specify a particular test function, use the `--match-test` option:

```sh
forge test --ffi --match-test testFunctionName
```

## Generate Coverage Report

To generate a coverage report, use:

```sh
forge coverage --ffi
```

You can use the same flags as in the test command to customize the coverage report.

## Generate ABI & Bytecode

1. Generate EVMAuth contract ABI:

```sh
forge inspect src/EVMAuth.sol:EVMAuth abi --json > src/EVMAuth.abi
```

2. Generate EVMAuth contract bytecode:

```sh
forge inspect src/EVMAuth.sol:EVMAuth bytecode > src/EVMAuth.bin
```

## SDKs & Libraries

EVMAuth provides the following SDKs and libraries for easy integration with applications and frameworks:

- [TypeScript SDK](https://github.com/evmauth/evmauth-ts)

To request additional SDKs or libraries, create a new issue with the `question` label.

## Additional Resources

- [Intro to Smart Contracts](https://docs.soliditylang.org/en/v0.8.0/introduction-to-smart-contracts.html)
- [Solidity Docs](https://docs.soliditylang.org/en/v0.8.0/)
- [Forge Docs](https://getfoundry.sh/forge/overview)
- [Forge Tests](https://getfoundry.sh/forge/tests/overview)
- [OpenZeppelin Upgrades](https://docs.openzeppelin.com/contracts/5.x/upgradeable)
- [OpenZeppelin Foundry Upgrades](https://github.com/OpenZeppelin/openzeppelin-foundry-upgrades)

## Contributing

To contribute to this open source project, please follow the guidelines in the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## License

The **EVMAuth** contract is released under the MIT License. See the [LICENSE](LICENSE) file for details.

[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-6909]: https://eips.ethereum.org/EIPS/eip-6909
