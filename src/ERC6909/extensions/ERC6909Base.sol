// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {
    IERC6909,
    IERC6909ContentURI,
    IERC6909Metadata,
    IERC6909TokenSupply
} from "@openzeppelin/contracts/interfaces/draft-IERC6909.sol";
import {ERC6909} from "@openzeppelin/contracts/token/ERC6909/draft-ERC6909.sol";
import {ERC6909ContentURI} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909ContentURI.sol";
import {ERC6909Metadata} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909Metadata.sol";
import {ERC6909TokenSupply} from "@openzeppelin/contracts/token/ERC6909/extensions/draft-ERC6909TokenSupply.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @dev Implementation of an ERC-6909 compliant contract with extended features.
 * This contract consolidates ERC6909 with the ContentURI, Metadata, and TokenSupply extensions.
 * It serves as a base contract for more complex implementations.
 */
abstract contract ERC6909Base is ERC6909ContentURI, ERC6909Metadata, ERC6909TokenSupply, Pausable {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC6909, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Override the `_update` function implemented by multiple inherited contracts.
    function _update(address from, address to, uint256 id, uint256 amount)
        internal
        virtual
        override(ERC6909, ERC6909TokenSupply)
        whenNotPaused
    {
        super._update(from, to, id, amount);
    }
}
