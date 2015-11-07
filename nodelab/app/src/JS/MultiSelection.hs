module JS.MultiSelection where

import           Utils.PreludePlus
import           GHCJS.Foreign
import           Utils.Vector


foreign import javascript unsafe "app.displaySelectionBox($1, $2, $3, $4)"
    displaySelectionBoxJS :: Double -> Double -> Double -> Double -> IO ()

displaySelectionBox :: Vector2 Double -> Vector2 Double -> IO ()
displaySelectionBox (Vector2 x0 y0) (Vector2 x1 y1) = displaySelectionBoxJS x0 y0 x1 y1

foreign import javascript unsafe "app.hideSelectionBox()"
    hideSelectionBox :: IO ()