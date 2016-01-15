---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# OPTIONS_GHC -fno-warn-type-defaults #-}

module Flowbox.Debug  where

import qualified Control.Concurrent    as Concurrent
import           Data.Time.Clock       (diffUTCTime, getCurrentTime)
import           Flowbox.Control.Error (MonadIO, liftIO)
import           Flowbox.Prelude
import           System.CPUTime        (getCPUTime)



timeit :: MonadIO m => String -> m a -> m a
timeit label action = do
    putStrLn $ ">>>>> " ++ label
    start  <- liftIO getCPUTime
    start' <- liftIO getCurrentTime
    r      <- action
    end    <- liftIO getCPUTime
    end'   <- liftIO getCurrentTime
    let diff  = fromIntegral (end - start) / (10^12)
        diff' = diffUTCTime end' start'
    putStrLn $ "<<<<< " ++ label ++ ": " ++ show (diff :: Double) ++ " CPU  " ++ show diff' ++ " TOTAL"
    return r


sleep :: MonadIO m => String  -> m ()
sleep msg = do
    putStrLn msg
    liftIO $ Concurrent.threadDelay 2000000