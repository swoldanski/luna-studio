{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TemplateHaskell #-}


import Generator.Generator
import Generator.Expr

-- import Data.Binary
import Generator.Binary
-- import Generator.Binary.Class

import qualified Language.Haskell.TH as TH
import qualified Language.Haskell.TH.Quote as THQ

import qualified Genrator.AST.Lit

instance Binary Generator.AST.Lit
instance Binary Accessor
instance Binary Expr
instance Binary Name
instance Binary a => Binary (Arg a)

main = do
	putStrLn "Generator 2 im. Arystotelesa."
	let con0 = Con 100 "[fooBarBazBarfooBarBazBarfooBarBazBarfooBarBazBar]"
	let args = [NestingEvil [con0]] :: [Arg Expr]
	let con = App 1200 (TypeDef 76 "typ1" "Typ2") args
	let imp = Import 4613 ["foo1 日本穂ショック！", "foo2", "foo3", "foo4"] con (Just "opcjonalny tekst")
	let argexp = Arg 4321 (0) (Just imp)
	let lit = Lit 500 (AST.Lit.IntLit 400)

	let acc = Accessor 503 (ConAccessor "bar") (Con 502 "foo")

	--let bs = encode con

	--encodeFile "../../sample_deserializer/test.bin" con
	--encodeFile "../../sample_deserializer/testimp.bin" imp
	--encodeFile "../../sample_deserializer/testargexp.bin" argexp
	--encodeFile "../../sample_deserializer/testlit.bin" lit
	encodeFile "../../sample_deserializer/testacc.bin" ("foo")

	--putStrLn $ show $ encode acc

	--encodeFile "../../sample_deserializer/testname.bin" (NameA "Foo blah" 34864296 500.750)

	--putStrLn "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
	--ns <- decodeFile "../../sample_deserializer/testout.bin" :: IO Expr
	--putStrLn $ show ns
	--putStrLn "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"

	---- $(THQ.dataToExpQ (const Nothing) (formatCppWrapper ''Expr))
	---- putStrLn $(TH.stringE . printAst =<< TH.reify ''Expr)
	---- putStrLn $(TH.stringE . TH.pprint =<< TH.reify ''Expr)

	-- $(generateCpp ''Expr "../../sample_deserializer/generated")
