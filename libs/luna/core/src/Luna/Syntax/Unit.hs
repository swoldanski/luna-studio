---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
module Luna.Syntax.Unit where

import Flowbox.Prelude
import GHC.Generics    (Generic)



data Unit a = Unit { _fromUnit :: a } deriving (Generic, Show)

makeLenses ''Unit

instance Unwrap  Unit where unwrap = view fromUnit
instance Wrap    Unit where wrap = Unit
instance Wrapper Unit
