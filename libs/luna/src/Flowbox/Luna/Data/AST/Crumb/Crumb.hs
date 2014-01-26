---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.Luna.Data.AST.Crumb.Crumb where

import Flowbox.Prelude



data Crumb = FunctionCrumb { name :: String }
           | ClassCrumb    { name :: String }
           | ModuleCrumb   { name :: String }
           deriving (Show)
