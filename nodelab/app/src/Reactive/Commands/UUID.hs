module Reactive.Commands.UUID
    ( registerRequest
    , unregisterRequest
    , isOwnRequest
    ) where

import qualified Data.Set                  as Set
import           Data.UUID.Types           (UUID)
import           Data.UUID.Types.Internal  (buildFromBytes)
import           Utils.PreludePlus

import           Reactive.Commands.Command (Command)
import           Reactive.State.Global     (State, nextRandom, pendingRequests)

getUUID :: Command State UUID
getUUID = do
  [b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, ba, bb, bc, bd, be, bf] <- mapM (const nextRandom) [1..16]
  return $ buildFromBytes 4 b0 b1 b2 b3 b4 b5 b6 b7 b8 b9 ba bb bc bd be bf

registerRequest :: Command State UUID
registerRequest = do
    uuid <- getUUID
    pendingRequests %= Set.insert uuid
    return uuid

unregisterRequest :: UUID -> Command State ()
unregisterRequest uuid = pendingRequests %= Set.delete uuid

isOwnRequest :: UUID -> Command State Bool
isOwnRequest uuid = uses pendingRequests $ Set.member uuid
