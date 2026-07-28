// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract CairoBridge {
    uint256 public nonce; // unique nonce for preventing message reply
    bytes32 public constant CAIRO_BRIDGE_PREFIX = keccak256("CAIRO_BRIDGE"); // prefix for message sending

    struct AdditionalData {
        uint256 executionFee;
        bytes message;
    }

    address public owner; // the oner of the contract that can accept given hashes
    mapping(bytes32 => bool) public acceptedHashes;
    mapping(bytes32 => bool) public claimedMessages;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    receive() external payable {}

    constructor(address _owner) {
        owner = _owner;
    }

    // The oner accepts that this hash is delivered from the source
    function acceptMessageHash(bytes32 hash) external onlyOwner {
        acceptedHashes[hash] = true;
    }

    // Send message from source chain to the destination chain
    function sendMessage(
        uint256 destinationChainId,
        bytes memory additionalData,
        bytes memory recipient
    ) public payable returns (bytes32) {
        AdditionalData memory additionalDataStruct = abi.decode(
            additionalData,
            (AdditionalData)
        );
        uint256 executionFee = additionalDataStruct.executionFee;
        bytes memory message = additionalDataStruct.message;

        require(msg.value >= executionFee, "Not enough funds");
        uint256 amount = msg.value - executionFee;
        require(amount > 0, "Amount must be greater than 0");

        // NOTE: this check is a must but since in testnet we are using the same chain id for all chains, we are skipping it for now
        // require(block.chainid != destinationChainId, "Invalid destination chain id");

        require(
            (message.length > 0 && executionFee > 0) ||
                (message.length == 0 && executionFee == 0),
            "executionFee and message must be provided together"
        );

        bytes32 messageHash;
        if (message.length > 0) {
            messageHash = keccak256(
                abi.encodePacked(
                    CAIRO_BRIDGE_PREFIX,
                    msg.sender,
                    nonce,
                    block.chainid,
                    destinationChainId,
                    amount,
                    recipient,
                    executionFee,
                    keccak256(message)
                )
            );
        } else {
            messageHash = keccak256(
                abi.encodePacked(
                    CAIRO_BRIDGE_PREFIX,
                    msg.sender,
                    nonce,
                    block.chainid,
                    destinationChainId,
                    amount,
                    recipient
                )
            );
        }
        nonce = nonce + 1;
        return messageHash;
    }

    // receive message on destination chain
    function claimMessage(
        bytes32 messageHash,
        uint256 sourceChainId,
        uint256 _nonce,
        address sender,
        bytes memory recipient,
        uint256 amount,
        uint256 executionFee,
        bytes memory message
    ) external {
        require(acceptedHashes[messageHash], "Message hash not accepted");
        require(!claimedMessages[messageHash], "Message already claimed");
        // NOTE: this check is a must but since in testnet we are using the same chain id for all chains, we are skipping it for now
        // require(block.chainid != sourceChainId, "Invalid source chain id");

        bytes32 expectedHash;
        if (message.length > 0) {
            expectedHash = keccak256(
                abi.encodePacked(
                    CAIRO_BRIDGE_PREFIX,
                    sender,
                    _nonce,
                    sourceChainId,
                    block.chainid,
                    amount,
                    recipient,
                    executionFee,
                    keccak256(message)
                )
            );
        } else {
            expectedHash = keccak256(
                abi.encodePacked(
                    CAIRO_BRIDGE_PREFIX,
                    sender,
                    _nonce,
                    sourceChainId,
                    block.chainid,
                    amount,
                    recipient
                )
            );
        }

        require(messageHash == expectedHash, "Invalid message hash");

        claimedMessages[messageHash] = true;

        // Decode recipient as address
        require(recipient.length == 20, "Recipient bytes length invalid");
        address recipientAddress;
        assembly {
            recipientAddress := mload(add(recipient, 32))
        }

        // If there is execution fee, send it to msg.sender
        if (executionFee > 0) {
            (bool feeSent, ) = msg.sender.call{value: executionFee}("");
            require(feeSent, "Execution fee transfer failed");
        }

        // Send the amount to recipient
        if (amount > 0) {
            (bool success, ) = recipientAddress.call{value: amount}("");
            require(success, "Value transfer to recipient failed");
        }

        // If there is data, call CairoBridgeReceived on recipient
        if (message.length > 0) {
            (bool called, ) = recipientAddress.call(
                abi.encodeWithSignature(
                    "CairoBridgeReceived(address,uint256,bytes)",
                    sender,
                    amount,
                    message
                )
            );
            require(called, "CairoBridgeReceived call failed");
        }
    }
}
