{-# LANGUAGE OverloadedStrings #-}

module Reactive.State.Graph where

import           Utils.PreludePlus            hiding ((.=))
import           Utils.Vector

import           Data.Map.Lazy                (Map)
import qualified Data.Map.Lazy                as Map
import qualified Data.Text.Lazy               as Text
import           Debug.Trace
import           Data.UUID.Types              (UUID)

import           Data.Aeson
import           Empire.API.Data.Connection   (Connection (..), ConnectionId)
import qualified Empire.API.Data.Connection   as Connection
import           Empire.API.Data.Node         (Node, NodeId)
import qualified Empire.API.Data.Node         as Node
import           Empire.API.Data.Port         (Port)
import qualified Empire.API.Data.Port         as Port
import           Empire.API.Data.PortRef      (AnyPortRef, InPortRef, OutPortRef)
import           Empire.API.Data.PortRef      (InPortRef)
import qualified Empire.API.Data.PortRef      as PortRef
import qualified Empire.API.JSONInstances     ()
-- import           Utils.Aeson                  (intMapToJSON)
import           Reactive.Commands.Command    (Command)

type NodesMap       = Map UUID Node
type ConnectionsMap = Map InPortRef Connection

data State = State { _nodesMap         :: NodesMap       -- don't access it directly
                   , _connectionsMap   :: ConnectionsMap -- don't access it directly
                   } deriving (Show, Eq, Generic)

makeLenses ''State

instance ToJSON State

-- instance Eq State where
--     a == b = (a ^. nodesMap) == (b ^. nodesMap)

instance Default State where
    def = State def def

connectionToNodeIds :: Connection -> (NodeId, NodeId)
connectionToNodeIds conn = ( conn ^. Connection.src . PortRef.srcNodeId
                           , conn ^. Connection.dst . PortRef.dstNodeId)

-- genId :: Map a -> Int
-- genId intMap = if Map.null intMap then 0
--                                   else 1 + (fst $ Map.findMax intMap)
-- genNodeId :: State -> NodeId
-- genNodeId state = genId $ state ^. nodesMap

getNode :: State -> NodeId -> Node
getNode state nodeId = Map.findWithDefault (error $ "Node " <> show nodeId <> " not found") nodeId $ state ^. nodesMap

getNodeById :: State -> NodeId -> Maybe Node
getNodeById state nodeId = Map.lookup nodeId $ state ^. nodesMap

nodes :: Getter State [Node]
nodes = to getNodes

getNodes :: State -> [Node]
getNodes = Map.elems . getNodesMap

getNodesMap :: State -> NodesMap
getNodesMap = (^. nodesMap)

getConnections :: State -> [Connection]
getConnections = Map.elems . getConnectionsMap

getConnectionsMap :: State -> ConnectionsMap
getConnectionsMap = (^. connectionsMap)

getConnectionNodeIds :: ConnectionId -> State -> Maybe (NodeId, NodeId)
getConnectionNodeIds connId state = connectionToNodeIds <$> conn
    where conn = lookUpConnection state connId

updateNodes :: NodesMap -> State -> State
updateNodes newNodesMap state = state & nodesMap .~ newNodesMap

getPort :: State -> AnyPortRef -> Port
getPort state portRef = fromMaybe err $ node ^? Node.ports . ix (portRef ^. PortRef.portId) where
    node  = getNode state $ portRef ^. PortRef.nodeId
    err   = error $ "Port " <> show portRef <> " not found"

addNode :: Node -> State -> State
addNode newNode state  = state & nodesMap     %~ Map.insert (newNode ^. Node.nodeId) newNode

removeNode :: NodeId -> State -> State
removeNode remNodeId state = state & nodesMap %~ Map.delete remNodeId

addConnection :: OutPortRef -> InPortRef -> Command State ConnectionId
addConnection sourcePortRef destPortRef = do
    connectionsMap %= (Map.insert destPortRef $ Connection sourcePortRef destPortRef)
    return destPortRef

removeConnections :: [ConnectionId] -> State -> State
removeConnections connIds state = foldr removeConnection state connIds

removeConnection :: ConnectionId -> State -> State
removeConnection connId state = state & connectionsMap %~ Map.delete connId

lookUpConnection :: State -> ConnectionId -> Maybe Connection
lookUpConnection state connId = Map.lookup connId $ getConnectionsMap state

containsNode :: NodeId -> Connection -> Bool
containsNode id conn = (startsWithNode id conn)
                    || (endsWithNode id conn)

startsWithNode :: NodeId -> Connection -> Bool
startsWithNode id conn = conn ^. Connection.src . PortRef.srcNodeId == id

endsWithNode :: NodeId -> Connection -> Bool
endsWithNode id conn = conn ^. Connection.dst . PortRef.dstNodeId == id

connectionsContainingNode :: NodeId -> State -> [Connection]
connectionsContainingNode id state = filter (containsNode id) $ getConnections state

connectionIdsContainingNode :: NodeId -> State -> [ConnectionId]
connectionIdsContainingNode id state = (^. Connection.connectionId) <$> connectionsContainingNode id state

connectionsStartingWithNode :: NodeId -> State -> [Connection]
connectionsStartingWithNode id state = filter (startsWithNode id) $ getConnections state

connectionsEndingWithNode :: NodeId -> State -> [Connection]
connectionsEndingWithNode id state = filter (endsWithNode id) $ getConnections state

hasConnections :: NodeId -> State -> Bool
hasConnections nodeId state = not . null $ connectionsContainingNode nodeId state
