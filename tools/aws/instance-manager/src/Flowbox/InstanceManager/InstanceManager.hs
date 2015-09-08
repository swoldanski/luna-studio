---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}

module Flowbox.InstanceManager.InstanceManager where

import qualified AWS
import qualified AWS.EC2.Types as Types
import qualified Data.Maybe    as Maybe
import qualified Data.Text     as Text

import qualified Flowbox.AWS.EC2.Control.Simple.Instance as Instance
import qualified Flowbox.AWS.EC2.EC2                     as EC2
import qualified Flowbox.AWS.EC2.Instance.Management     as Management
import qualified Flowbox.AWS.EC2.Instance.Request        as Request
import           Flowbox.AWS.Region                      (Region)
import qualified Flowbox.AWS.User.User                   as User
import qualified Flowbox.InstanceManager.Cmd             as Cmd
import           Flowbox.Prelude
import           Flowbox.System.Log.Logger


userName :: User.Name
userName = "flowbox"


logger :: LoggerIO
logger = getLoggerIO $moduleName


getCredential :: Cmd.Options -> IO AWS.Credential
getCredential = AWS.loadCredentialFromFile . Cmd.credentialPath


instanceIP :: Types.Instance -> String
instanceIP inst = Maybe.maybe "(no ip)" show $ Types.instanceIpAddress inst


printInstance :: Types.Instance -> IO ()
printInstance inst = putStrLn $ concat
    [Text.unpack $ Types.instanceId inst, " ", instanceIP inst]


start :: Region -> Cmd.Options -> IO ()
start region options = do
    credential <- getCredential options
    [inst] <- EC2.runEC2inRegion credential region $ do
        let request = Request.mk { Types.runInstancesRequestImageId      = Text.pack        $ Cmd.ami options
                                 , Types.runInstancesRequestInstanceType = Just $ Text.pack $ Cmd.machine options
                                 , Types.runInstancesRequestKeyName      = Just $ Text.pack $ Cmd.keyName options
                                 }
        Instance.getOrStartWait userName request
    let command = "ssh -i " ++ Cmd.keyName options ++ ".pem ec2-user@" ++ instanceIP inst
    logger info $ "You can login using command " ++ show command
    printInstance inst


stop :: Region -> Cmd.Options -> IO ()
stop region options = do
    credential <- getCredential options
    EC2.runEC2inRegion credential region $ do
        instances <- filter Management.ready <$> Instance.findInstances
        let instanceIDs = map Types.instanceId instances
        if null instances
            then logger info "No instances to stop."
            else do logger info $ "Stopping " ++ show (length instances) ++ " instances."
                    _ <- EC2.stopInstances instanceIDs $ Cmd.force options
                    return ()


get :: Region -> Cmd.Options -> IO ()
get region options = do
    credential <- getCredential options
    instances <- EC2.runEC2inRegion credential region Instance.findInstances
    mapM_ printInstance $ filter Management.ready instances


terminate :: Region -> Cmd.Options -> IO ()
terminate region options = do
    credential <- getCredential options
    EC2.runEC2inRegion credential region $ do
        instances <- Instance.findInstances
        let instanceIDs = map Types.instanceId instances
        if null instances
            then logger info "No instances to terminate."
            else do logger info $ "Terminating " ++ show (length instances) ++ " instances."
                    _ <- EC2.terminateInstances instanceIDs
                    return ()
