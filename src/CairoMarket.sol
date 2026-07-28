// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title CairoMarket
/// @notice A minimal two-sided bonding-curve market.
///         Each market has TRUST votes and DISTRUST votes. The price of a single
///         vote on a side is that side's share of the total supply, scaled by
///         `BASE_PRICE`:
///
///             trustPrice    = trustVotes    * BASE_PRICE / (trust + distrust)
///             distrustPrice = distrustVotes * BASE_PRICE / (trust + distrust)
///
///         The two prices always sum to BASE_PRICE. Votes are bought/sold one at
///         a time, the price re-evaluated after every unit.
///
contract CairoMarket {
    uint256 public constant BASE_PRICE = 1 ether;

    // Genesis votes (start at 1 each) keep the denominator non-zero and are not
    // owned by anyone, so users can never sell the supply below this floor.
    uint256 public trustVotes = 1;
    uint256 public distrustVotes = 1;

    mapping(address => uint256) public trustOwned;
    mapping(address => uint256) public distrustOwned;

    /// @notice Deploy funded with initial reserve liquidity (prior activity).
    constructor() payable {}

    function trustPrice() public view returns (uint256) {
        return (trustVotes * BASE_PRICE) / (trustVotes + distrustVotes);
    }

    function distrustPrice() public view returns (uint256) {
        return (distrustVotes * BASE_PRICE) / (trustVotes + distrustVotes);
    }

    function buyTrust(uint256 amount) external payable {
        uint256 cost;
        for (uint256 i = 0; i < amount; i++) {
            cost += (trustVotes * BASE_PRICE) / (trustVotes + distrustVotes);
            trustVotes += 1;
        }
        require(msg.value >= cost, "insufficient payment");
        trustOwned[msg.sender] += amount;
        if (msg.value > cost) {
            _pay(msg.sender, msg.value - cost);
        }
    }

    function buyDistrust(uint256 amount) external payable {
        uint256 cost;
        for (uint256 i = 0; i < amount; i++) {
            cost += (distrustVotes * BASE_PRICE) / (trustVotes + distrustVotes);
            distrustVotes += 1;
        }
        require(msg.value >= cost, "insufficient payment");
        distrustOwned[msg.sender] += amount;
        if (msg.value > cost) {
            _pay(msg.sender, msg.value - cost);
        }
    }

    function sellTrust(uint256 amount) external {
        require(trustOwned[msg.sender] >= amount, "not enough votes");
        uint256 proceeds;
        for (uint256 i = 0; i < amount; i++) {
            trustVotes -= 1;
            proceeds +=
                (trustVotes * BASE_PRICE) /
                (trustVotes + distrustVotes);
        }
        trustOwned[msg.sender] -= amount;
        _pay(msg.sender, proceeds);
    }

    function sellDistrust(uint256 amount) external {
        require(distrustOwned[msg.sender] >= amount, "not enough votes");
        uint256 proceeds;
        for (uint256 i = 0; i < amount; i++) {
            distrustVotes -= 1;
            proceeds +=
                (distrustVotes * BASE_PRICE) /
                (trustVotes + distrustVotes);
        }
        distrustOwned[msg.sender] -= amount;
        _pay(msg.sender, proceeds);
    }

    function _pay(address to, uint256 value) private {
        (bool ok, ) = to.call{value: value}("");
        require(ok, "transfer failed");
    }
}
