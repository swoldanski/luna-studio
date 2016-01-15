{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}

module Flowbox.WSConnector.Workers.BusWorker (start) where

import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import           Flowbox.Control.Error

import           Control.Concurrent.STM        (atomically)
import           Control.Concurrent.STM.TChan
import           Control.Concurrent            (forkIO)
import           Control.Monad                 (forever)
import           Flowbox.Bus.Bus               (Bus)
import qualified Flowbox.Bus.Bus               as Bus
import           Flowbox.Bus.EndPoint          (BusEndPoints)
import qualified Flowbox.Bus.Data.Flag         as Flag
import qualified Flowbox.Bus.Data.Message      as Message
import qualified Flowbox.Bus.Data.MessageFrame as MessageFrame

import           Flowbox.WSConnector.Data.WSMessage (WSMessage(..))

logger :: LoggerIO
logger = getLoggerIO $moduleName

relevantTopics :: [String]
relevantTopics =  ["empire."]

shouldPassToClient :: MessageFrame.MessageFrame -> Message.ClientID -> Bool
shouldPassToClient frame clientId = isNotSender where
    isNotSender      = senderId /= clientId
    senderId         = frame ^. MessageFrame.senderID

-- shouldPassToClient frame clientId = isOriginalAuthor && isNotSender where
--     isOriginalAuthor = originalAuthorId == clientId
--     originalAuthorId = frame ^. MessageFrame.correlation . Message.clientID
--     isNotSender      = senderId /= clientId
--     senderId         = frame ^. MessageFrame.senderID

fromBus :: TChan WSMessage -> TChan Message.ClientID -> Bus ()
fromBus chan idChan = do
    mapM_ Bus.subscribe relevantTopics
    senderAppId <- liftIO $ atomically $ readTChan idChan
    forever $ do
        frame <- Bus.receive
        when (shouldPassToClient frame senderAppId) $ do
            let msg = frame ^. MessageFrame.message
            logger info $ "Received from Bus: " ++ (show msg)
            liftIO $ atomically $ writeTChan chan $ WebMessage (msg ^. Message.topic)
                                                               (msg ^. Message.message)

dispatchMessage :: WSMessage -> Bus ()
dispatchMessage (WebMessage topic msg) = do
    logger info $ "Pushing to Bus: " ++ (show msg)
    void $ Bus.send Flag.Enable $ Message.Message topic msg
dispatchMessage _ = return ()

toBus :: TChan WSMessage -> TChan Message.ClientID -> Bus ()
toBus chan idChan = do
    myId <- Bus.getClientID
    liftIO $ atomically $ writeTChan idChan myId
    forever $ do
        msg <- liftIO $ atomically $ readTChan chan
        dispatchMessage msg

start :: BusEndPoints -> TChan WSMessage -> TChan WSMessage -> IO ()
start busEndPoints fromBusChan toBusChan = do
    exchangeIdsChan <- atomically newTChan
    forkIO $ eitherToM' $ Bus.runBus busEndPoints $ fromBus fromBusChan exchangeIdsChan
    forkIO $ eitherToM' $ Bus.runBus busEndPoints $ toBus   toBusChan   exchangeIdsChan
    return ()