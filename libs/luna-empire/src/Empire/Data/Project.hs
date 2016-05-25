module Empire.Data.Project where

import           Prologue
import qualified Data.Text.Lazy          as Text
import           Empire.Data.Library     (Library)
import qualified Empire.Data.Library     as Library
import qualified Empire.API.Data.Project as API
import qualified Empire.API.Persistence.Project as Persistence
import qualified Empire.API.Persistence.Library as Persistence
import           Data.IntMap             (IntMap)
import qualified Data.IntMap             as IntMap

data Project = Project { _name     :: String
                       , _libs     :: IntMap Library
                       } deriving (Show)

make :: String -> Project
make name = Project name IntMap.empty

makeLenses ''Project

toAPI :: Project -> API.Project
toAPI (Project name libs) = API.Project name (Library.toAPI <$> libs)

toPersistent :: Project -> IntMap Persistence.Library -> Persistence.Project
toPersistent (Project name _) = Persistence.Project name
