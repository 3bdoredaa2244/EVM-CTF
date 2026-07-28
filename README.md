# 0xCairo III: Security Day — EVM CTF

![0xCairo 3 EVM CTF](./EVM%20CTF%20Poster-selection.png)

A set of **4 hands-on EVM security challenges** built with [Foundry](https://book.getfoundry.sh/).
Each challenge ships a deliberately vulnerable contract in `src/` and a matching
test in `test/` where you write your exploit. Break the contract, make the test
pass, collect the points.

| #   | Challenge                                  | Category           | Points  |
| --- | ------------------------------------------ | ------------------ | :-----: |
| 1   | [CairoAuction](#challenge-1--cairoauction) | Security Standards | **10**  |
| 2   | [CairoVault](#challenge-2--cairovault)     | EVM Architecture   | **20**  |
| 3   | [CairoMarket](#challenge-3--cairomarket)   | Mathematics        | **35**  |
| 4   | [CairoBridge](#challenge-4--cairobridge)   | Encoding & Hashing | **50**  |
|     |                                            | **Total**          | **115** |

---

## 1. Setup

### 1.1 Install Foundry

If you **don't** already have Foundry, install it from the official source:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

Then restart your terminal (or `source` your shell profile) and run the installer:

```bash
foundryup
```

### 1.2 Update Foundry

If Foundry is **already** installed, make sure it's up to date:

```bash
foundryup
```

### 1.3 Verify the installation

```bash
forge --version
cast --version
anvil --version
```

You should see a version string for each. If a command is not found, re-open your
terminal so the updated `PATH` is picked up.

### 1.4 Install the repository

```bash
# Clone with submodules (forge-std is a git submodule)
git clone --recurse-submodules https://github.com/<your-username>/0xCairo-III-Security-Day.git
cd 0xCairo-III-Security-Day

# If you cloned without --recurse-submodules, pull the libs manually:
git submodule update --init --recursive

# Compile everything
forge build
```

---

## 2. How the CTF works

Every challenge follows the same layout:

- **`src/<Name>.sol`** — the vulnerable contract. **Read it, don't modify it.**
- **`test/<Name>.t.sol`** — the challenge harness. Your job is to fill in the
  section marked `// Write your code here`.

Most harnesses are gated behind a flag so the suite stays green until you start:

```solidity
bool startCtf = false; // NOTE: turn this to true when testing
```

Flip it to `true`, write your exploit in the marked block, and run **only** that
challenge's test contract:

```bash
forge test --match-contract <Name>Test -vvv
```

A challenge is **solved** when its test passes. Use `-vvvv` for full execution
traces while debugging.

> Tip: run a single test function with `--match-test`, e.g.
> `forge test --match-test test_DrainCairoVault -vvv`.

---

## 3. The Challenges

### Challenge 1 — CairoAuction

**Category:** Security Standards · **Points:** 10

An open English auction. Bidders compete and the highest bidder wins the trophy
when time runs out.

**Objective:** Make sure **Alice never wins** — arrange things so that **no one
can overbid you**. Once you are on top, every future bid (Alice's included) must
fail, locking in your victory.

- Contract: `src/CairoAuction.sol`
- Harness: `test/CairoAuction.t.sol` → `test_AttackerWinAuction`
- Run:
    ```bash
    forge test --match-contract CairoAuctionTest -vvv
    ```

---

### Challenge 2 — CairoVault

**Category:** EVM Architecture · **Points:** 20

A vault holding **10 ETH**, sealed behind a hashed secret and an owner-only check.
It publishes only the _hash_ of the answer, so it looks impossible to open.

**Objective:** **Drain the vault's entire balance.** You'll need to recover the
secret phrase whose hash matches the on-chain commitment **and** bypass the
identity/owner validation — even though you are not the owner.

- Contract: `src/CairoVault.sol`
- Harness: `test/CairoVault.t.sol` → `test_DrainCairoVault`
- Run:
    ```bash
    forge test --match-contract CairoVaultTest -vvv
    ```

---

### Challenge 3 — CairoMarket

**Category:** Mathematics · **Points:** 35

A two-sided **bonding-curve** market. Each market has `TRUST` and `DISTRUST`
votes; the price of a vote on each side is its share of the total supply scaled
by a base price. Votes are bought and sold one unit at a time.

**Objective:** **Extract money from the market.** You must finish with **more ETH
than you started with**, while the market's reserve **decreases**. You do _not_
need to fully drain it — a net profit is enough.

- Contract: `src/CairoMarket.sol`
- Harness: `test/CairoMarket.t.sol` → `test_DrainCairoMarket`
- Run:
    ```bash
    forge test --match-contract CairoMarketTest -vvv
    ```

---

### Challenge 4 — CairoBridge

**Category:** Encoding & Hashing · **Points:** 40

A cross-chain message bridge. A message is committed on the **source** chain and
later claimed on the **destination** chain, keyed by a message hash.

**Objective:** **Forge a message.** Deceive the bridge into accepting a message
on the source chain and then **relaying it with different parameters** on the
destination chain — so what gets claimed is not what was actually sent. Look
closely at how the message hash is constructed from its inputs.

- Contract: `src/CairoBridge.sol`
- Harness: `test/CairoBridge.t.sol` → `test_drainDstBridgeBalance`
- Run:
    ```bash
    forge test --match-contract CairoBridgeTest -vvv
    ```

---

## 4. Rules

- **Do not modify the contracts in `src/`.** Solve everything from the test harness.
- You may add helper contracts and functions inside the test files.
- A challenge counts only when its test passes on an unmodified `src/` contract.
- Points are independent — solve them in any order.

Good luck, and have fun breaking things. 🐫🔓
