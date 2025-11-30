# **FunDAO Protocol – README**

A decentralized funding protocol combining **prediction markets**, **evaluator governance**, and **quadratic-style scoring** to allocate capital to public-good projects in discrete funding rounds.

FunDAO coordinates three major subsystems:

- **Token House** (FUND token governance)
- **Evaluator House** (SBT-based governance of evaluators)
- **Prediction Markets** (LONG/SHORT markets for each project)
- **Funding Round System** (allocates funds using evaluator score + market score)

This repository contains the smart contracts implementing the protocol.

---

## 📚 **Architecture Overview**

---

## **1. Token House Governance (FUND + TokenHouseGovernor + Timelock)**

The Token House governs:

- Treasury funds
- Round budgets

### **Components**

| Contract         | Purpose                                                          |
| ---------------- | ---------------------------------------------------------------- |
| `FunDAOToken`    | FUND governance token with ERC20Votes; mintable only by Timelock |
| `TokenHouse`     | FUND-based governance (proposal → vote → queue → execute)        |
| `FunDaoTimelock` | Executes approved proposals and owns FUND minting & treasury     |

**Evaluator restriction:** Evaluators cannot hold FUND (enforced in token contract).

**Timelock control:** Only the Timelock may mint FUND and execute treasury actions.

---

## **2. Evaluator House (EvaluatorSBT + EvaluatorGovernor)**

The Evaluator House manages evaluator identity, membership, and project impact scoring.

### **Components**

| Contract            | Purpose                                                        |
| ------------------- | -------------------------------------------------------------- |
| `EvaluatorSBT`      | Soulbound ERC721 storing evaluator identity + reputation       |
| `EvaluatorGovernor` | SBT-based governance for evaluators + impact scoring proposals |

### **Impact Evaluation**

For each project:

impactScore = Σ(score \* reputation) / Σ(reputation)

Evaluators can:

- Add evaluators
- Remove evaluators
- Adjust reputation
- Vote on project impact (0–100 scores)
- Finalize impact score after voting period

---

## **3. Funding Markets (FundingMarket)**

For every project in a round, a **LONG/SHORT AMM-based prediction market** is created automatically.

### **Token meaning**

| Token     | Meaning                                   |
| --------- | ----------------------------------------- |
| **LONG**  | Pays proportional to final impact score S |
| **SHORT** | Pays proportional to 100 – S              |

### **Features**

- Buy/sell LONG or SHORT with ETH
- Liquidity added by Timelock
- LP trading revenue tracked
- Final score fetched from EvaluatorGovernor
- Redemption based on payout formula:

LONG pays: (S / 100) \* _ INITIAL_TOKEN_VALUE
SHORT pays: ((100 - S) / 100) \* _ INITIAL_TOKEN_VALUE

### **Market Score**

FundingRoundManager uses market score as:

marketScore = probLong \* 100

Where:

probLong = longSold / (longSold + shortSold)

---

## **4. Project Registry**

Allows anyone **except evaluators** to register a project in the active funding round.

### Responsibilities

- Collects a refundable project deposit
- Creates a new **FundingMarket** for each registered project
- Stores project metadata
- Tracks projects by owner and by round
- Returns deposits after round end

---

## **5. Funding Round Manager**

Handles the lifecycle and payout of funding rounds.

### **Workflow**

1. **TokenHouse → startRound(budget, endsAt)** (with ETH)
2. Projects register & Markets trade
3. Evaluators vote on impact scores
4. **TokenHouse → endCurrentRound()**

For each project:

finalScore = 80% \* evaluatorScore + 20% \* marketScore
payment = (capPerProject \* finalScore) / 100

Any unspent budget returns to Treasury.

Project owners withdraw using: withdrawAllPayments()

---

## **6. Evaluator Incentives**

Evaluators receive equal payments for participation.

### Workflow

1. Timelock funds the round using `fundRound()`
2. Evaluators register via `registerForRoundPayout(roundId)`
3. After round end, they withdraw:

payment = roundBudget / registeredEvaluators

## 🔒 **Security Notes**

- All ETH-sending methods use `nonReentrant`
- Strict `receive()`/`fallback()` protections
- Evaluators cannot hold FUND to avoid governance capture
- No upgradability to reduce governance-key risk
