// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title CairoVault
/// @notice A vault holding 10 ETH. To open it you must:
///           1. know the secret phrase whose keccak256 equals `answerHash`
///              (hint: "who won the 2022 World Cup?"), and
///           2. be the `owner`.
/// @dev    The owner check is broken. The contract validates the caller against
///         the *decoded* `sender` field, but re-reads the "admin" address from a
///         HARD-CODED calldata offset (where `sender` sits in a canonical call).
///         Because `abi.decode` honors the attacker-controlled outer offset while
///         the assembly read does not, the two can be decoupled — letting a
///         non-owner satisfy both checks at once.
contract CairoVault {
    address public owner;

    // Public commitment to the secret phrase. Reversing keccak256 is infeasible,
    // but the answer is a well-known fact given the hint.
    bytes32 public immutable answerHash;

    struct Input {
        address sender;
        string secret;
    }

    event VaultOpened(address indexed opener, uint256 amount);

    constructor(address _owner, bytes32 _answerHash) payable {
        owner = _owner;
        answerHash = _answerHash;
    }

    receive() external payable {}

    /// @notice Open the vault. `inputEncoded` must ABI-encode an `Input`.
    function unlock(bytes memory inputEncoded) external {
        _validateSecret(inputEncoded);

        address admin;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0x24, 0x20)
            admin := mload(ptr)
        }
        require(admin == owner, "not owner");

        // (4) Release everything to the caller.
        uint256 amount = address(this).balance;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");

        emit VaultOpened(msg.sender, amount);
    }

    function _validateSecret(bytes memory inputEncoded) internal view {
        Input memory userInput = abi.decode(inputEncoded, (Input));

        require(
            keccak256(abi.encodePacked(userInput.secret)) == answerHash,
            "Wrong answer"
        );

        require(userInput.sender == msg.sender, "sender != caller");
    }
}
