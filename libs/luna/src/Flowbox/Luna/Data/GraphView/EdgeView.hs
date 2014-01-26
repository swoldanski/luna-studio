---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.Luna.Data.GraphView.EdgeView where

import           Flowbox.Luna.Data.Graph.Edge               (Edge (Edge))
import qualified Flowbox.Luna.Data.Graph.Port               as Port
import           Flowbox.Luna.Data.GraphView.PortDescriptor (PortDescriptor)
import           Flowbox.Prelude



data EdgeView = EdgeView { src :: PortDescriptor
                         , dst :: PortDescriptor
                         } deriving (Show, Read, Ord, Eq)


fromEdge :: Edge -> EdgeView
fromEdge (Edge (Port.Num s) d) = EdgeView [s] [d]
fromEdge (Edge  Port.All    d) = EdgeView []  [d]


toEdge :: (Applicative m, Monad m) => EdgeView -> m Edge
toEdge (EdgeView src' dst') = do s <- case src' of
                                        [s] -> return $ Port.Num s
                                        []  -> return Port.All
                                        _   -> fail "Source ports with size greater than 1 are not supported"
                                 d <- case dst' of
                                        [d] -> return d
                                        _   -> fail "Destination ports with size other than 1 are not supported"
                                 return $ Edge s d


toLEdge :: (Applicative m, Monad m) => (s, d, EdgeView) -> m (s, d, Edge)
toLEdge (s, d, ev) = do e <- toEdge ev
                        return (s, d, e)
