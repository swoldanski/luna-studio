---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleInstances #-}

module Flowbox.Luna.Data.AST.Data where

import           Flowbox.Luna.Data.AST.Expr  (Expr)
import qualified Flowbox.Luna.Data.AST.Expr  as Expr
import           Flowbox.Luna.Data.AST.Type  (Type)
import           Flowbox.Luna.Data.AST.Utils (ID)


mk :: ID -> Type -> Expr -> Expr
mk id cls con = Expr.Data id cls [con] [] []
