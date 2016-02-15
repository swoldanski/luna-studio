{-# LANGUAGE RankNTypes           #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.Graph.Referenced.Ref (module Data.Graph.Referenced.Ref, module X) where

import Prelude.Luna

import Data.Construction
import Data.Direction    as X
import Data.Index
import Data.Layer
import Data.Prop
import Data.Graph.Model

-----------------
-- === Ref === --
-----------------

-- === Definitions === --

-- FIXME[WD]: Maybe we should parametrize the Ref to indicate the ref type, like Ref Node / Ref Edge / Ref Cluster / ...
--            We can then introduce Ref and TypedRef (used with homo- and hetero- graphs)
newtype Ref r a = Ref Int deriving (Show, Eq, Ord, Functor, Traversable, Foldable)
newtype Ptr r   = Ptr Int deriving (Show, Eq, Ord)

class Referred r a t where focus :: Ref r a -> Lens' t a


-- === Utils === --

retarget :: Ref r a -> Ref r a'
retarget = rewrap


-- === Instances === --

-- Wrappers
makeWrapped ''Ref

-- Ref primitive instances
type instance Uncovered     (Ref r a) = Uncovered a
type instance Unlayered     (Ref r a) = a
type instance Deconstructed (Ref r a) = a

-- Index
type instance Index  (Ref r a) = Int
instance      HasIdx (Ref r a) where idx = wrapped' ; {-# INLINE idx #-}

-- Conversions
instance Castable a a' => Castable (Ref r a) (Ref r' a') where cast = rewrap ; {-# INLINE cast #-}

-- Construction
instance Constructor m (Ref r a) => LayerConstructor m (Ref r a) where
    constructLayer = construct ; {-# INLINE constructLayer #-}


-- Hetero reference handling

-- | When referencing the Hetero graph, we query the underlying one for its native node and edge representations
--   by using `NodeOf` and `EdgeOf` families respectively.

instance (Referred Node n' a, BiCastable n n', n' ~ (a # Node))
      =>  Referred Node n (Hetero a) where focus r = wrapped' ∘ focus (cast r :: Ref Node n') ∘ casted ; {-# INLINE focus #-}
instance  Referred Node I (Hetero a) where focus   = impossible
instance  Referred Node n (Hetero I) where focus   = impossible

instance (Referred Edge e' a, BiCastable e e', e' ~ (a # Edge))
      =>  Referred Edge e (Hetero a) where focus r = wrapped' ∘ focus (cast r :: Ref Edge e') ∘ casted ; {-# INLINE focus #-}
instance  Referred Edge I (Hetero a) where focus   = impossible
instance  Referred Edge e (Hetero I) where focus   = impossible
