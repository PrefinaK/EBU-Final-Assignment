{-# LANGUAGE DataKinds #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE OverloadedStrings #-}

module OnChain.FundReleaseValidator where

import PlutusTx
import PlutusTx.Prelude
import Plutus.V2.Ledger.Api
import Plutus.V2.Ledger.Contexts
import Plutus.V1.Ledger.Interval as Interval

-------------------------------------------------
-- DATUM
-------------------------------------------------

data FundDatum = FundDatum
    { fdOwner        :: PubKeyHash
    , fdReceiver     :: PubKeyHash
    , fdCommittee    :: [PubKeyHash]
    , fdSigned       :: [PubKeyHash]
    , fdMinApprovals :: Integer
    , fdExpiry       :: POSIXTime
    }

PlutusTx.unstableMakeIsData ''FundDatum

-------------------------------------------------
-- REDEEMER
-------------------------------------------------

data FundAction
    = Sign
    | Withdraw
    | Reclaim

PlutusTx.unstableMakeIsData ''FundAction

-------------------------------------------------
-- HELPERS
-------------------------------------------------

{-# INLINABLE hasSigned #-}
hasSigned :: PubKeyHash -> ScriptContext -> Bool
hasSigned pkh ctx =
    txSignedBy (scriptContextTxInfo ctx) pkh

{-# INLINABLE stillValid #-}
stillValid :: POSIXTime -> ScriptContext -> Bool
stillValid expiry ctx =
    let currentTime = txInfoValidRange (scriptContextTxInfo ctx)
    in Interval.contains (to expiry) currentTime

{-# INLINABLE expired #-}
expired :: POSIXTime -> ScriptContext -> Bool
expired expiry ctx =
    let currentTime = txInfoValidRange (scriptContextTxInfo ctx)
    in Interval.contains (from expiry) currentTime

{-# INLINABLE isNewSigner #-}
isNewSigner :: PubKeyHash -> FundDatum -> Bool
isNewSigner pkh d =
    elem pkh (fdCommittee d) && not (elem pkh (fdSigned d))

-------------------------------------------------
-- VALIDATOR
-------------------------------------------------

{-# INLINABLE validate #-}
validate :: FundDatum -> FundAction -> ScriptContext -> Bool
validate datum action ctx =
    case action of

        -------------------------------------------------
        -- SIGN: committee member signs before expiry
        -------------------------------------------------
        Sign ->
            case txInfoSignatories info of
                [s] ->
                    traceIfFalse "expired" (stillValid (fdExpiry datum) ctx) &&
                    traceIfFalse "not allowed signer" (isNewSigner s datum)
                _ -> traceError "single signer required"

        -------------------------------------------------
        -- WITHDRAW: enough approvals + receiver signs
        -------------------------------------------------
        Withdraw ->
            traceIfFalse "expired" (stillValid (fdExpiry datum) ctx) &&
            traceIfFalse "not enough signatures" (length (fdSigned datum) >= fdMinApprovals datum) &&
            traceIfFalse "receiver not signed" (hasSigned (fdReceiver datum) ctx)

        -------------------------------------------------
        -- RECLAIM: expired + insufficient approvals
        -------------------------------------------------
        Reclaim ->
            traceIfFalse "still active" (expired (fdExpiry datum) ctx) &&
            traceIfFalse "already approved" (length (fdSigned datum) < fdMinApprovals datum) &&
            traceIfFalse "owner not signed" (hasSigned (fdOwner datum) ctx)

  where
    info = scriptContextTxInfo ctx

-------------------------------------------------
-- UNTYPED WRAPPER
-------------------------------------------------

{-# INLINABLE mkUntyped #-}
mkUntyped :: BuiltinData -> BuiltinData -> BuiltinData -> ()
mkUntyped d r c =
    let datum = unsafeFromBuiltinData @FundDatum d
        redeemer = unsafeFromBuiltinData @FundAction r
        ctx = unsafeFromBuiltinData @ScriptContext c
    in
        if validate datum redeemer ctx
            then ()
            else error ()

validator :: Validator
validator =
    mkValidatorScript
        $$(PlutusTx.compile [|| mkUntyped ||])