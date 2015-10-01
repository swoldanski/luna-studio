module Batch.Value where

import Utils.PreludePlus

data Value = FloatValue  Float
           | IntValue    Int
           | StringValue String
           | CharValue   Char
           | BoolValue   Bool
           deriving (Eq, Show)

instance PrettyPrinter Value where
    display (FloatValue  v) = "float "  <> display v
    display (IntValue    v) = "int "    <> show v
    display (StringValue v) = "string " <> show v
    display (CharValue   v) = "char "   <> show v
    display (BoolValue   v) = "bool "   <> show v
