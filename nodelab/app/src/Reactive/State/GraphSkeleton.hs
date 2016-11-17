module Reactive.State.GraphSkeleton where

import           Utils.PreludePlus

import           Data.Aeson
import qualified Data.Set                   as Set

import           Empire.API.Data.Connection (Connection)
import           Empire.API.Data.Node       (Node, NodeId)
import qualified Empire.API.Data.Node       as Node
import           Reactive.State.Graph       (State, connectionsContainingNodes, getNodes)


data GraphSkeleton = GraphSkeleton { _nodesList       :: [Node]
                                   , _connectionsList :: [Connection]
                                   } deriving (Show, Eq, Generic)

makeLenses ''GraphSkeleton
instance ToJSON GraphSkeleton
instance FromJSON GraphSkeleton

separateSubgraph :: [NodeId] -> State -> GraphSkeleton
separateSubgraph nodeIds' state = do
  let nodeIds = Set.fromList nodeIds'
      nodes   = filter (flip Set.member nodeIds . view Node.nodeId) $ getNodes state
  GraphSkeleton nodes (connectionsContainingNodes nodeIds state)