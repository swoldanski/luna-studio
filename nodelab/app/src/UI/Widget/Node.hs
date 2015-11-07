{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module UI.Widget.Node where

import           Utils.PreludePlus
import           Utils.Vector
import           Data.JSString.Text ( lazyTextFromJSString, lazyTextToJSString )
import           GHCJS.Types        (JSVal, JSString)
import           GHCJS.Marshal.Pure (PToJSVal(..), PFromJSVal(..))
import           GHCJS.DOM.Element  (Element)
import           UI.Widget          (UIWidget(..), UIContainer(..))
import qualified UI.Registry        as UIR
import           Event.Keyboard (KeyMods(..))
import qualified Reactive.State.UIRegistry as UIRegistry
import qualified Object.Widget.Node as Model
import           Object.Widget
import           Object.UITypes
import           Event.Mouse (MouseButton(..))
import qualified Event.Mouse as Mouse
import           Utils.CtxDynamic (toCtxDynamic)
import           Reactive.Commands.Command (Command, ioCommand, performIO)
import qualified Reactive.Commands.UIRegistry as UICmd
import qualified Reactive.State.Global as Global
import           UI.Widget (GenericWidget(..))
import qualified UI.Widget as UIT
import           UI.Generic (takeFocus)

newtype Node = Node { unNode :: JSVal } deriving (PToJSVal, PFromJSVal)

instance UIWidget    Node
instance UIContainer Node

foreign import javascript unsafe "new GraphNode(-1, new THREE.Vector2($2, $3), 0, $1)" create' :: WidgetId -> Double -> Double -> IO Node
foreign import javascript unsafe "$1.setExpandedStateBool($2)"     setExpandedState :: Node -> Bool     -> IO ()
foreign import javascript unsafe "$1.label($2)"                    setLabel         :: Node -> JSString -> IO ()
foreign import javascript unsafe "$1.setValue($2)"                 setValue         :: Node -> JSString -> IO ()
foreign import javascript unsafe "$1.uniforms.selected.value = $2" setSelected      :: Node -> Int      -> IO ()

foreign import javascript unsafe "$1.htmlContainer"                getHTMLContainer :: Node -> IO Element

createNode :: WidgetId -> Model.Node -> IO Node
createNode id model = do
    node <- create' id (model ^. Model.position . x) (model ^. Model.position . y)
    setLabel node $ lazyTextToJSString $ model ^. Model.expression
    return node

selectedState :: Getter Model.Node Int
selectedState = to selectedState' where
    selectedState' model
        | model ^. Model.isFocused  = 2
        | model ^. Model.isSelected = 1
        | otherwise                 = 0

setSelectedState :: Node -> Model.Node -> IO ()
setSelectedState node model = setSelected node $ model ^. selectedState

unselectNode :: WidgetId -> Command (UIRegistry.State a) ()
unselectNode = flip UICmd.update (Model.isSelected .~ False)


ifChanged :: (Eq b) => a -> a -> Lens' a b -> IO () -> IO ()
ifChanged old new get action = if (old ^. get) /= (new ^. get) then action
                                                               else return ()

instance UIDisplayObject Model.Node where
    createUI parentId id model = do
        node   <- createNode id model
        parent <- UIR.lookup parentId :: IO GenericWidget
        UIR.register id node
        UIT.add node parent

    updateUI id old model = do
        node <- UIR.lookup id :: IO Node

        setSelectedState node model
        setExpandedState node (model ^. Model.isExpanded)

        ifChanged old model Model.expression $ do
            setLabel node $ lazyTextToJSString $ model ^. Model.expression

        ifChanged old model Model.value $ do
            setValue node $ lazyTextToJSString $ model ^. Model.value


keyPressedHandler :: KeyPressedHandler Global.State
keyPressedHandler '\r' _ id = zoom Global.uiRegistry $ UICmd.update id (Model.isExpanded %~ not)
keyPressedHandler _ _ _ = return ()

handleSelection :: Mouse.Event' -> WidgetId -> Command Global.State ()
handleSelection evt id = case evt ^. Mouse.keyMods of
    KeyMods False False False False -> zoom Global.uiRegistry $ performSelect id
    KeyMods False False True  False -> zoom Global.uiRegistry $ toggleSelect  id
    otherwise                       -> return ()

performSelect :: WidgetId -> Command (UIRegistry.State a) ()
performSelect id = do
    isSelected <- UICmd.get id Model.isSelected
    unless isSelected $ do
        unselectAll
        UICmd.update id (Model.isSelected .~ True)

toggleSelect :: WidgetId -> Command (UIRegistry.State a) ()
toggleSelect id = UICmd.update id (Model.isSelected %~ not)

unselectAll :: Command (UIRegistry.State a) ()
unselectAll = do
    widgets <- allNodes
    let widgetIds = (^. objectId) <$> widgets
    forM_ widgetIds $ (flip UICmd.update) (Model.isSelected .~ False)

widgetHandlers :: UIHandlers Global.State
widgetHandlers = def & keyPressed   .~ keyPressedHandler
                     & mouseOver    .~ (\id -> performIO (putStrLn $ "Over" <> (show id)))
                     & mouseOut     .~ (\id -> performIO (putStrLn $ "Out" <> (show id)))
                     & mousePressed .~ (\evt id -> do
                         takeFocus evt id
                         handleSelection evt id)


allNodes :: Command (UIRegistry.State a) [WidgetFile a Model.Node]
allNodes = UIRegistry.lookupAllM