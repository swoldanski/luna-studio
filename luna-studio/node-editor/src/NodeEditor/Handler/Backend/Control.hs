module NodeEditor.Handler.Backend.Control
    ( handle
    ) where

import           Common.Action.Command         (Command)
import           Common.Prelude
import           Common.Report                 (fatal)
import           Control.Concurrent            (threadDelay)
import qualified LunaStudio.Data.GraphLocation as GraphLocation
import qualified NodeEditor.Action.Batch       as Batch
import           NodeEditor.Action.State.App   (getWorkspace)
import           NodeEditor.Batch.Workspace    (currentLocation)
import qualified NodeEditor.Event.Batch        as Batch
import           NodeEditor.Event.Event        (Event (Batch))
import           NodeEditor.State.Global       (State)


handle :: Event -> Maybe (Command State ())
handle (Batch (Batch.EmpireStarted _)) = Just $ do
    liftIO $ threadDelay 5000000
    workspace <- getWorkspace
    withJust workspace $ \ws -> do
        let gl = ws ^. currentLocation
        liftIO $ putStrLn "nodeeditor"
        Batch.openFile $ gl ^. GraphLocation.filePath
        liftIO $ putStrLn "opened"
        Batch.getProgram Nothing True

handle _ = Nothing
