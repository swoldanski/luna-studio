---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------

module Luna.Codegen.Hs.Import (
    Import(..),
    noItems,
    qualified,
    simple,
    regular,
    genCode
)where

import qualified Luna.Codegen.Hs.Path            as Path
import           Luna.Codegen.Hs.Path              (Path)
import           Data.String.Utils                 (join)


data Import = Regular   {path :: Path, item :: String} 
            | Qualified {path :: Path}
            deriving (Show, Ord, Eq)


noItems :: String
noItems = ""


qualified :: Path -> Import
qualified path = Qualified path


simple :: Path -> Import
simple path = Regular path noItems


regular :: Path -> String -> Import
regular path item = Regular path item


genCode :: Import -> String
genCode imp = "import " ++ body where
    paths = Path.toModulePaths (path imp) 
    src = join "." paths
    body = case imp of
        Regular _ item -> src ++ els where
                               els = if item == ""
                                   then ""
                                   else " (" ++ item ++ ")"
        Qualified _     -> "qualified " ++ src -- ++ " as " ++ last paths