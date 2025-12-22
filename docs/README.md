# Public Fund Release Smart Contract (Anti-Corruption)

# Table of Contents 

# EBU Public Fund Release Smart Contract (include)

## Problem Overview
## System Architecture
## On-Chain Smart Contract Design
## Off-Chain Application Design
## Workflow Sequence
## Emulator Behavior (Conceptual)
## Diagrams
## Project Structure
## Limitations
## Demo Video
## Conclusion


## 1. Overview

Public funds are often vulnerable to misuse due to lack of transparency, single-point authority, and weak approval mechanisms. This project proposes a **blockchain-based governance smart contract** built on **Cardano using Plutus**, designed to prevent unauthorized or premature release of public funds.

The contract enforces:

* Locked funds on-chain
* Multi-signature approval (n-of-m officials)
* Time-based conditions (deadline)
* Automatic refund when conditions are not met

By encoding these rules directly into a smart contract, the system reduces corruption risks and increases accountability, auditability, and trust.

---

## 2. Problem Statement

In traditional systems:

* One individual can approve fund release
* Approvals are not publicly verifiable
* Funds can be released after deadlines without consequence

These weaknesses create opportunities for corruption.

**Goal:**
Ensure that public funds are released **only** when:

* A minimum number of authorized officials approve
* The approval happens before a predefined deadline
* All actions are verifiable on-chain

---

## 3. High-Level Architecture

The system is divided into **three logical layers**:

### Components

1. **Users / Officials**

   * Depositor (locks funds)
   * Committee officials (approve)
   * Beneficiary (receives funds)

2. **Off-Chain Layer (Client / Endpoints)**

   * Deposit endpoint
   * Approve endpoint
   * Release endpoint
   * Refund endpoint

3. **On-Chain Layer (Plutus Smart Contract)**

   * Datum (stores state)
   * Redeemer (action intent)
   * Validator (enforces rules)

---

### Architecture Diagram (Conceptual)

```
+------------------+
|  Depositor       |
+------------------+
          |
          | Deposit Funds
          v
+-----------------------------+
|   Plutus Smart Contract     |
|-----------------------------|
| Datum:                      |
| - Owner                     |
| - Receiver                  |
| - Committee                 |
| - Approvals                 |
| - Required Approvals        |
| - Deadline                  |
+-----------------------------+
          ^           ^
          |           |
   Approve|           |Withdraw / Refund
          |           |
+----------------+  +------------------+
| Officials (n)  |  | Beneficiary      |
+----------------+  +------------------+
```

(Visual version will be placed in `diagrams/architecture.jpg`)

---

## 4. Workflow Sequence

### Step-by-Step Flow

1. **Deposit Phase**

   * Depositor locks funds in the contract
   * Datum is created with deadline and committee list

2. **Approval Phase**

   * Each committee member signs once
   * Duplicate approvals are rejected
   * Approvals must occur before deadline

3. **Release Phase**

   * If approvals ≥ required number
   * Beneficiary signs
   * Funds are released

4. **Refund Phase**

   * If deadline passes
   * Approvals < required
   * Depositor reclaims funds

---

### Workflow Diagram (Conceptual)

```
[Deposit Funds]
       |
       v
[Funds Locked in Contract]
       |
       v
[Officials Approve]
       |
       +----> (Enough approvals?) ---- No ----> [Wait until deadline]
       |                                      |
      Yes                                     v
       |                                [Refund to Depositor]
       v
[Beneficiary Withdraws Funds]
```

(Visual version will be placed in `diagrams/workflow.jpg`)

---

## 5. Smart Contract Design

### Datum (On-Chain State)

The datum stores all governance information:

* Fund owner
* Fund receiver
* Committee members
* Collected approvals
* Minimum required approvals
* Expiry deadline

This ensures the contract is **stateful and transparent**.

---

### Redeemer (User Intent)

The redeemer communicates **what action** is being performed:

* `Sign` – official approval
* `Withdraw` – release funds
* `Reclaim` – refund funds

---

### Validator Logic

The validator enforces rules strictly:

* **Sign**

  * Must be committee member
  * Must not have signed before
  * Must be before deadline

* **Withdraw**

  * Must be before deadline
  * Must have enough approvals
  * Beneficiary must sign

* **Reclaim**

  * Must be after deadline
  * Must have insufficient approvals
  * Depositor must sign

This guarantees **no unauthorized fund movement**.

---

## 6. Security & Anti-Corruption Properties

✔ Multi-signature enforcement
✔ No single authority control
✔ Time-locked funds
✔ Fully verifiable on-chain
✔ Immutable approval history

---

## 7. Limitations

* Emulator-based testing only (no mainnet deployment)
* Committee list is static per contract instance
* Does not support approval revocation
* Requires correct off-chain coordination

These limitations can be addressed in future iterations.



Smart Contract Data Structure

Include as part of architecture diagram or separately:

FundDatum:
  fdOwner        :: PubKeyHash
  fdReceiver     :: PubKeyHash
  fdCommittee    :: [PubKeyHash]
  fdSigned       :: [PubKeyHash]
  fdMinApprovals :: Integer
  fdExpiry       :: POSIXTime

FundAction:
  Sign | Withdraw | Reclaim


  

---

## 8. Conclusion

This project demonstrates how **blockchain governance** and **smart contracts** can be used to reduce corruption in public fund management. By enforcing approvals, deadlines, and signatures on-chain, the system removes trust from individuals and places it in transparent, verifiable code.

---

## 9. Future Improvements

* Dynamic committee updates
* On-chain approval tracking per signer
* Integration with identity frameworks
* Deployment on Cardano testnet
