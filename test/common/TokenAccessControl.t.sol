// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTestWithRoles } from "test/BaseTestWithRoles.sol";
import { TokenAccessControl } from "src/common/TokenAccessControl.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MockTokenAccessControl is TokenAccessControl, UUPSUpgradeable {
    function initialize(uint48 initialDelay, address initialDefaultAdmin) public initializer {
        __TokenAccessControl_init(initialDelay, initialDefaultAdmin);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADE_MANAGER_ROLE) {
        // This will revert if the caller does not have the UPGRADE_MANAGER_ROLE
    }
}

contract TokenAccessControl_Test is BaseTestWithRoles {
    MockTokenAccessControl internal token;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);

        // Deploy the proxy and initialize
        proxy = deployUUPSProxy(
            "MockTokenAccessControl", abi.encodeCall(MockTokenAccessControl.initialize, (2 days, owner))
        );
        token = MockTokenAccessControl(proxy);

        // Grant roles
        token.grantRole(token.ACCESS_MANAGER_ROLE(), accessManager);
        token.grantRole(token.TOKEN_MANAGER_ROLE(), tokenManager);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.BURNER_ROLE(), burner);
        token.grantRole(token.TREASURER_ROLE(), treasurer);

        vm.stopPrank();
    }
}
