{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}

module Empire.Data.Graph where

import           Empire.Data.BreadcrumbHierarchy   (HasRefs(..), LamItem)
import           Empire.Prelude

import           Control.Monad.State               (MonadState(..), StateT, evalStateT, lift)
import           Data.Map                          (Map)
import qualified Data.Map                          as Map
import           Empire.Data.AST                   (NodeRef, SomeASTException)
import           Empire.Data.Layers                (attachEmpireLayers)

-- import           Control.Monad.Raise                    (MonadException(..))
import qualified Control.Monad.State.Layered          as DepState
-- import qualified Luna.Builtin.Data.Function             as Function
import           Luna.IR.Term.Ast.Invalid (Symbol(FunctionBlock))
import qualified Luna.IR                                as IR
-- import qualified Luna.Runner                                as Runner
-- import qualified OCI.Pass.Class                         as Pass
import qualified Luna.Pass        as Pass
import qualified Luna.Pass.Attr         as Attr

import qualified OCI.Pass.Management.Scheduler                       as Scheduler
import qualified Data.Graph.Data.Graph.Class                       as LunaGraph
import qualified Empire.Pass.PatternTransformation            as PT

-- import qualified OCI.Pass.Manager                       as PassManager (PassManager, State)
import           LunaStudio.Data.Node                   (NodeId)
import           LunaStudio.Data.NodeCache
import           LunaStudio.Data.NodeMeta               (NodeMeta)
import           Luna.Pass.Data.Stage (Stage)

-- import           Luna.Syntax.Text.Parser.Errors         (Invalids)
-- import qualified Luna.Syntax.Text.Parser.Marker         as Luna
-- import qualified Luna.Syntax.Text.Parser.Parser         as Parser
-- import qualified Luna.Syntax.Text.Parser.Parsing        as Parser ()
import Luna.Syntax.Text.Parser.State.Marker (ID)
import qualified Luna.Syntax.Text.Parser.Data.CodeSpan       as CodeSpan
import           Data.Text.Position                     (Delta)

-- import           System.Log                             (Logger, DropLogger, dropLogs, MonadLogging)

-- import qualified OCI.IR.Repr.Vis            as Vis
import           Data.Aeson                 (encode)
import qualified Data.ByteString.Lazy.Char8 as ByteString
import           Data.Maybe                 (isJust)
import           System.Environment         (lookupEnv)
import           Web.Browser                (openBrowser)
-- import           Luna.Pass.Data.ExprMapping

type MarkerId = ID

data CommandState s = CommandState { _pmState   :: PMState
                                   , _userState :: s
                                   }

instance Show s => Show (CommandState s) where
    show (CommandState _ s) = "CommandState { " <> show s <> "}"

data PMState = PMState { _pmScheduler :: Scheduler.State
                       , _pmStage     :: LunaGraph.State Stage
                       }

makeLenses ''CommandState
makeLenses ''PMState

defaultPMState :: IO PMState
defaultPMState = do
    (scState, grState) <- LunaGraph.encodeAndEval @Stage $ do
        ((), schedulerState) <- Scheduler.runT $ return ()
        graphState <- LunaGraph.getState
        return (schedulerState, graphState)
    return $ PMState scState grState


instance Show PMState where show _ = "PMState"


data Graph = Graph { _breadcrumbHierarchy   :: LamItem
                   , _codeMarkers           :: Map MarkerId NodeRef
                   , _globalMarkers         :: Map MarkerId NodeRef
                   , _graphCode             :: Text
                   , _parseError            :: Maybe SomeException
                   , _fileOffset            :: Delta
                   , _graphNodeCache        :: NodeCache
                   } deriving Show

data FunctionGraph = FunctionGraph { _funName    :: String
                                   , _funGraph   :: Graph
                                   , _funMarkers :: Map MarkerId NodeRef
                                   } deriving Show

data ClsGraph = ClsGraph { _clsClass       :: NodeRef
                         , _clsCodeMarkers :: Map MarkerId NodeRef
                         , _clsCode        :: Text
                         , _clsParseError  :: Maybe SomeException
                         , _clsFuns        :: Map NodeId FunctionGraph
                         , _clsNodeCache   :: NodeCache
                         } deriving Show

instance HasRefs Graph where
    refs fun (Graph a b c d e f g) = Graph <$> refs fun a <*> traverse fun b <*> traverse fun c <*> pure d <*> pure e <*> pure f <*> pure g

instance HasRefs FunctionGraph where
    refs fun (FunctionGraph a b c) = FunctionGraph a <$> refs fun b <*> traverse fun c

instance HasRefs ClsGraph where
    refs fun (ClsGraph a b c d e f) = ClsGraph <$> fun a <*> traverse fun b <*> pure c <*> pure d <*> (traverse.refs) fun e <*> pure f

instance MonadState s m => MonadState s (DepState.StateT b m) where
    get = lift   get
    put = lift . put

makeLenses ''Graph
makeLenses ''FunctionGraph
makeLenses ''ClsGraph

-- breadcrumbHierarchy :: Lens' (CommandState Graph) LamItem
-- breadcrumbHierarchy = userState . breadcrumbHierarchyOld

-- codeMarkers :: Lens' (CommandState Graph) (Map MarkerId NodeRef)
-- codeMarkers = userState . codeMarkersOld

-- globalMarkers :: Lens' (CommandState Graph) (Map MarkerId NodeRef)
-- globalMarkers = userState . globalMarkersOld

-- fileOffset :: Lens' (CommandState Graph) Delta
-- fileOffset = userState . fileOffsetOld

-- clsClass :: Lens' (CommandState ClsGraph) NodeRef
-- clsClass = userState . clsClassOld

-- clsFuns :: Lens' (CommandState ClsGraph) (Map NodeId FunctionGraph)
-- clsFuns = userState . clsFunsOld

-- instance MonadState s m => MonadState s (PassManager.PassManager m) where
--     get = lift   get
--     put = lift . put

-- instance MonadState s m => MonadState s (Logger DropLogger m) where
--     get = lift   get
--     put = lift . put

-- instance Exception e => MonadException e IO where
--     raise = throwM

-- unescapeUnaryMinus :: Vis.Node -> Vis.Node
-- unescapeUnaryMinus n = if n ^. Vis.name == "Var \"#uminus#\""
--                        then n & Vis.name .~ "Var uminus"
--                        else n

-- withVis :: MonadIO m => Vis.VisStateT m a -> m a
-- withVis m = do
--     (p, vis) <- Vis.newRunDiffT m
--     when (not . null $ vis ^. Vis.steps) $ do
--         let unescaped = vis & Vis.nodes %~ Map.map unescapeUnaryMinus
--             cfg = ByteString.unpack $ encode unescaped
--         showVis <- liftIO $ lookupEnv "DEBUGVIS"
--         if isJust showVis then void $ liftIO $ openBrowser $ "http://localhost:8000?cfg=" <> cfg else return ()
--     return p
withVis = id

-- data InitPass
-- type instance Pass.Spec InitPass t = InitPassSpec t
-- type family InitPassSpec t where
--     InitPassSpec (Pass.In  Pass.Attrs)  = '[]
--     InitPassSpec (Pass.Out Pass.Attrs)  = '[RetAttr]
--     InitPassSpec (Pass.In  AnyExpr)     = '[IR.Model, IR.Users, IR.Type]
--     InitPassSpec (Pass.Out AnyExpr)     = '[IR.Model, IR.Users, IR.Type]
--     InitPassSpec (Pass.In  AnyExprLink) = '[IR.Model, IR.Users, IR.Type, IR.Source, IR.Target]
--     InitPassSpec (Pass.Out AnyExprLink) = '[IR.Model, IR.Users, IR.Type, IR.Source, IR.Target]
--     InitPassSpec t                    = Pass.BasicPassSpec t

-- newtype RetAttr = RetAttr Int deriving (Show, Eq, Num)
-- type instance Attr.Type RetAttr = Attr.Atomic
-- instance Default RetAttr where
--     def = RetAttr 0

-- Pass.cache_phase1 ''InitPass
-- Pass.cache_phase2 ''InitPass



-- type OnDemandPass pass = (Typeable pass, Pass.Compile pass IO)

-- runPass :: forall pass. OnDemandPass pass => Pass.Pass pass () -> IO ()
-- runPass pass = Scheduler.runManual registers passes
--     where
--         registers = do
--             -- Runner.registerAll
--             attachEmpireLayers

--         passes = do
--             -- Scheduler.registerAttr     @RetAttr
--             -- Scheduler.enableAttrByType @RetAttr
--             Scheduler.registerPassFromFunction__ pass
--             Scheduler.runPassByType @pass

initExprMapping :: IO ()
initExprMapping = return ()

snapshot :: IO ()
snapshot = return ()


-- defaultClsGraph :: IO ClsGraph
-- defaultClsGraph = do
--     (ast, cls) <- defaultClsAST
--     return $ ClsGraph ast cls def def def def def


-- defaultPMState :: IO (PMState a)
-- defaultPMState = runPass $ mdo
--     -- CodeSpan.init
--     attachLayer @CodeSpan.CodeSpan @AnyExpr
--     attachEmpireLayers
--     initExprMapping
--     pass <- DepState.get @Scheduler.State
--     return $ PMState pass def

-- emptyClsAST :: IO (AST ClsGraph)
-- emptyClsAST = mdo
--     let g = ClsGraph ast undefined def def def def (NodeCache def def def)
--     ast <- runPass $ do
--         -- CodeSpan.init
--         attachLayer @CodeSpan.CodeSpan @AnyExpr
--         attachEmpireLayers
--         initExprMapping
--         st   <- snapshot
--         pass <- DepState.get @Scheduler.State
--         return $ AST st $ PMState pass def
--     return ast

-- defaultClsAST :: IO (AST ClsGraph, SomeExpr)
-- defaultClsAST = mdo
--     let g = ClsGraph ast undefined def def def def (NodeCache def def def)
--     (ast, cls) <- runPass $ do
--         -- CodeSpan.init
--         attachLayer @CodeSpan.CodeSpan @AnyExpr
--         attachEmpireLayers
--         initExprMapping
--         cls <- do
--             -- hub   <- IR.importHub' []
--             -- cls   <- IR.invalid FunctionBlock
--             -- klass <- IR.unit' hub [] cls
--             -- return klass
--             undefined
--         st   <- snapshot
--         pass <- DepState.get @Scheduler.State
--         return (AST st (PMState pass def), cls)
--     return (ast, cls)



class HasCode g where
    code :: Lens' g Text

instance HasCode (Graph) where
    code = graphCode

instance HasCode (ClsGraph) where
    code = clsCode

instance HasCode a => HasCode (CommandState a) where
    code = userState . code

class HasNodeCache g where
    nodeCache :: Lens' g NodeCache

instance HasNodeCache (Graph) where
    nodeCache = graphNodeCache

instance HasNodeCache (ClsGraph) where
    nodeCache = clsNodeCache

instance HasNodeCache a => HasNodeCache (CommandState a) where
    nodeCache = userState . nodeCache