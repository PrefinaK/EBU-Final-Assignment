{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE NumericUnderscores #-}

module FundReleaseEndpoints where

import Control.Monad (void)
import Data.Text (Text)

-- Plutus / Ledger
import Ledger
import Ledger.Ada as Ada
import Plutus.Contract
import Plutus.Trace.Emulator as Emulator

import Wallet.Emulator.Wallet

-- Import your on-chain validator
import OnChain.FundReleaseValidator

------------------------------------------------------------
-- Contract Schema
------------------------------------------------------------

type FundSchema =
        Endpoint "deposit" ()
    .\/ Endpoint "approveFund" ()
    .\/ Endpoint "releaseFund" ()
    .\/ Endpoint "refundFund" ()

------------------------------------------------------------
-- Script Address
------------------------------------------------------------

fundAddress :: Address
fundAddress = scriptAddress fundValidator

------------------------------------------------------------
-- Datum constructor
------------------------------------------------------------

createDatum :: Wallet -> Wallet -> [Wallet] -> POSIXTime -> FundDatum
createDatum depositor beneficiary approvers deadline =
    FundDatum
        { fdDepositor   = mockWalletPaymentPubKeyHash depositor
        , fdBeneficiary = mockWalletPaymentPubKeyHash beneficiary
        , fdOfficials   = fmap mockWalletPaymentPubKeyHash approvers
        , fdApprovals   = []
        , fdRequired    = 2
        , fdDeadline    = deadline
        }

------------------------------------------------------------
-- Deposit Endpoint
------------------------------------------------------------

deposit :: Contract () FundSchema Text ()
deposit = do
    let datum =
            createDatum
                (knownWallet 1)
                (knownWallet 2)
                [knownWallet 3, knownWallet 4]
                25_000

        tx =
            mustPayToTheScript
                datum
                (Ada.lovelaceValueOf 15_000_000)

    void $ submitTxConstraints fundValidator tx

------------------------------------------------------------
-- Approve Endpoint
------------------------------------------------------------

approveFund :: Contract () FundSchema Text ()
approveFund = do
    utxos <- utxosAt fundAddress
    case utxos of
        [(oref, _)] ->
            void $
              submitTxConstraintsSpending
                fundValidator
                utxos
                (mustSpendScriptOutput
                    oref
                    (Redeemer $ toBuiltinData Approve))
        _ -> logError @String "No fund UTxO found"

------------------------------------------------------------
-- Release Endpoint
------------------------------------------------------------

releaseFund :: Contract () FundSchema Text ()
releaseFund = do
    utxos <- utxosAt fundAddress
    case utxos of
        [(oref, _)] ->
            void $
              submitTxConstraintsSpending
                fundValidator
                utxos
                (mustSpendScriptOutput
                    oref
                    (Redeemer $ toBuiltinData Release))
        _ -> logError @String "Release failed: no UTxO"

------------------------------------------------------------
-- Refund Endpoint
------------------------------------------------------------

refundFund :: Contract () FundSchema Text ()
refundFund = do
    utxos <- utxosAt fundAddress
    case utxos of
        [(oref, _)] ->
            void $
              submitTxConstraintsSpending
                fundValidator
                utxos
                (mustSpendScriptOutput
                    oref
                    (Redeemer $ toBuiltinData Refund))
        _ -> logError @String "Refund failed"

------------------------------------------------------------
-- Emulator Trace
------------------------------------------------------------

fundTrace :: EmulatorTrace ()
fundTrace = do
    hDeposit <- activateContractWallet (knownWallet 1) deposit
    void $ Emulator.waitNSlots 1

    hApprove1 <- activateContractWallet (knownWallet 3) approveFund
    void $ Emulator.waitNSlots 1

    hApprove2 <- activateContractWallet (knownWallet 4) approveFund
    void $ Emulator.waitNSlots 1

    hRelease <- activateContractWallet (knownWallet 2) releaseFund
    void $ Emulator.waitNSlots 1

------------------------------------------------------------
-- Run Emulator
------------------------------------------------------------

runFundEmulator :: IO ()
runFundEmulator =
    runEmulatorTraceIO fundTrace
