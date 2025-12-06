# **FunDAO – Decentralized Funding Protocol**

A fully on-chain protocol that allocates funding to public-good projects using a combination of:

- **Prediction markets**
- **Evaluator consensus**
- **Token House (FUND) governance**
- **Timelock-controlled treasury**

This repository contains **only the smart contracts** implementing the protocol.  
A frontend is **not included** in this version.

---

# 📐 **System Architecture**

The protocol consists of four major subsystems:

1. **Token House Governance** — FUND token holders govern treasury usage & round budgets
2. **Evaluator House Governance** — evaluator identity, reputation, and impact scoring
3. **Prediction Markets** — LONG/SHORT markets per project capturing market sentiment
4. **Funding Rounds** — allocation of funds using evaluator score + market score

---

# 1. **Token House Governance**

( `FunDAOToken.sol`, `TokenHouseGovernor.sol`, `FunDaoTimelock.sol` )

The Token House controls all treasury spending and high-level protocol actions.

### Components

| Contract           | Purpose                                                                 |
| ------------------ | ----------------------------------------------------------------------- |
| **FunDAOToken**    | ERC20Votes governance token (FUND). Mintable only by timelock.          |
| **TokenHouse**     | Governance module (proposal → vote → queue → execute).                  |
| **FunDaoTimelock** | Timelock + treasury. Executes approved proposals and mints FUND tokens. |

### Notes

- Evaluators are **forbidden** from holding FUND (enforced in the token contract).
- Treasury ETH is held by the **timelock**, ensuring all spending is governance-gated.
- Rounds, evaluator payments, market liquidity adjustments, and registry funding all require proposals.

---

# 2. **Evaluator House Governance**

( `EvaluatorSBT.sol`, `EvaluatorGovernor.sol` )

Manages evaluator identity, governance, and scoring.

### Components

| Contract              | Purpose                                                       |
| --------------------- | ------------------------------------------------------------- |
| **EvaluatorSBT**      | Soulbound token representing evaluator identity + reputation. |
| **EvaluatorGovernor** | SBT-based governance system for evaluators.                   |

### Capabilities

- Add or remove evaluators
- Modify evaluator reputation
- Submit and vote on **impact scores** for each project
- Finalize project impact scores after voting period

---

# 3. **Prediction Markets**

( `FundingMarket.sol`, `FundingMarketToken.sol` )

Each registered project in a round receives a LONG/SHORT AMM-based prediction market.

### Token Payout Logic

| Token     | Pays                                       |
| --------- | ------------------------------------------ |
| **LONG**  | proportional to _finalImpactScore_         |
| **SHORT** | proportional to _(100 - finalImpactScore)_ |

### Market Behavior

- Users may buy/sell LONG or SHORT using ETH
- Markets become operational immediately once **initial liquidity is added by ProjectRegistry**
- Further liquidity additions or withdrawals can be made **only by the timelock**
- LONG/SHORT tokens are minted when liquidity is added and burned when redeemed

---

# 4. **Project Registry**

( `ProjectRegistry.sol` )

Allows anyone **except evaluators** to register projects for the active funding round.

### Responsibilities

- Stores project metadata
- Collects refundable project deposits
- Creates a **FundingMarket** for each project
- Holds a **liquidity budget**, funded by the DAO
- Seeds each new FundingMarket with **initial liquidity**
- Tracks projects by round & owner

### DAO Funding Model

- The DAO periodically sends ETH to `ProjectRegistry`
- Registry uses this liquidity budget when instantiating markets
- Markets are thus **born liquid**, improving usability and reducing governance overhead

The timelock continues to have ultimate control over liquidity via governance actions.

---

# 5. **Funding Round Manager**

( `FundingRoundManager.sol` )

Coordinates the lifecycle and payouts of funding rounds.

### Workflow

1. **TokenHouse → startRound(budget, endsAt)** (via governance proposal)
2. Projects register; Markets trade
3. Evaluators score each project
4. **TokenHouse → endCurrentRound()**
   - Evaluator and market scores are combined
   - Payments are calculated and allocated

Unused round budget is returned to the treasury.

---

# 6. **Evaluator Incentives**

( `EvaluatorIncentives.sol` )

Ensures evaluators are compensated for round participation.

### Lifecycle

1. The DAO funds the evaluator pool
2. Evaluators register for that round’s payout
3. After the round ends, each registered evaluator can withdraw

---

# 🧪 **Development**

This repository uses **Foundry** for smart contract development.

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Build

```
forge build
```

### Test

```
forge test
```

## Frontend

This repository is a smart-contract–only implementation of the FunDAO protocol.
