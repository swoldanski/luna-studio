---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE Rank2Types #-}

module Flowbox.Luna.Passes.Transform.HAST.HASTGen.HASTGen where

import qualified Flowbox.Prelude                                     as Prelude
import           Flowbox.Prelude                                     hiding (error, id, mod, simple)
import qualified Flowbox.Luna.Data.AST.Expr                          as LExpr
import qualified Flowbox.Luna.Data.AST.Type                          as LType
import qualified Flowbox.Luna.Data.AST.Pat                           as LPat
import qualified Flowbox.Luna.Data.AST.Lit                           as LLit
import qualified Flowbox.Luna.Data.AST.Module                        as LModule
import qualified Flowbox.Luna.Data.HAST.Expr                         as HExpr
import qualified Flowbox.Luna.Data.HAST.Lit                          as HLit
import qualified Flowbox.Luna.Data.HAST.Module                       as HModule
import qualified Flowbox.Luna.Data.HAST.Extension                    as HExtension
import qualified Flowbox.Luna.Passes.Transform.HAST.HASTGen.GenState as GenState
import           Flowbox.Luna.Passes.Transform.HAST.HASTGen.GenState   (GenState)
import           Flowbox.Luna.Passes.Analysis.FuncPool.Pool            (Pool)
import qualified Flowbox.Luna.Passes.Analysis.FuncPool.Pool          as Pool
import qualified Flowbox.Luna.Passes.Pass                            as Pass
import           Flowbox.Luna.Passes.Pass                              (Pass)
import           Flowbox.System.Log.Logger
import           Flowbox.Luna.Passes.Transform.HAST.HASTGen.Utils
import qualified Luna.Target.HS.Naming                               as Naming
import           Data.String.Utils                                     (join)
import qualified Data.Set                                            as Set
import qualified Flowbox.Luna.Data.HAST.Deriving                     as Deriving
import           Flowbox.Luna.Data.HAST.Deriving                     (Deriving)

import           Control.Monad.State                                 hiding (mapM, mapM_, join)



type GenPass m = Pass GenState m

type LExpr   = LExpr.Expr
type LType   = LType.Type
type LModule = LModule.Module


logger :: LoggerIO
logger = getLoggerIO "Flowbox.Luna.Passes.Transform.HAST.HASTGen.HASTGen"


run :: LModule -> Pool -> Pass.Result HExpr
run = (Pass.run_ (Pass.Info "HASTGen") GenState.empty) .: genModule


stdDerivings :: [Deriving]
stdDerivings = [Deriving.Show, Deriving.Eq, Deriving.Ord, Deriving.Generic]


genModule :: LModule -> Pool -> GenPass HExpr
genModule lmod@(LModule.Module _ cls imports classes typeAliases typeDefs fields methods _) fpool = do
    let (LType.Module _ path) = cls
        --fnames  = Set.toList $ Pool.names fpool
        mod     = HModule.addImport ["Luna", "Target", "HS", "Core"]
                $ HModule.addImport ["Flowbox", "Graphics", "Mockup"]
                -- $ HModule.addExt HExtension.AutoDeriveTypeable
                $ HModule.addExt HExtension.DataKinds
                $ HModule.addExt HExtension.DeriveDataTypeable
                $ HModule.addExt HExtension.DeriveGeneric
                $ HModule.addExt HExtension.FlexibleInstances
                $ HModule.addExt HExtension.MultiParamTypeClasses
                $ HModule.addExt HExtension.NoMonomorphismRestriction
                $ HModule.addExt HExtension.RebindableSyntax
                $ HModule.addExt HExtension.ScopedTypeVariables
                $ HModule.addExt HExtension.TemplateHaskell
                -- $ HModule.addExt HExtension.TypeFamilies
                $ HModule.addExt HExtension.UndecidableInstances
                $ HModule.mk path
        name    = last path
        params  = view LType.params cls
        modCon  = LExpr.ConD 0 name fields
    
    GenState.setModule mod
    
    mapM_ genExpr classes

    GenState.setCls    cls

    -- DataType
    (consE, consTH) <- genCon name modCon
    GenState.addDataType $ HExpr.DataD name params [consE] stdDerivings
    consTH
    
    GenState.addTHExpression $ thGenerateAccessors name
    GenState.addTHExpression $ thRegisterAccessors name
    GenState.addTHExpression $ thInstsAccessors name
    
    mapM_ genExpr methods
    
    mapM_ (genExpr >=> GenState.addImport) imports
    when (name == "Main") $ do
        let funcnames = map (view LExpr.name) methods
        if not $ "main" `elem` funcnames
            then logger warning "No 'main' function defined." *> GenState.addFunction mainEmpty
            else GenState.addFunction mainf
    GenState.getModule


mainf :: HExpr
mainf = HExpr.Function "main" []
      $ HExpr.DoBlock [   HExpr.Arrow (HExpr.Var "m")
                        $ HExpr.AppE (HExpr.Var "call0")
                        $ HExpr.Var "con_Main"
                      ,   mkGetIO
                        $ mkCall0
                        $ HExpr.AppE (mkMemberGetter "main")
                        $ HExpr.Var "m"
                      ]

mainEmpty :: HExpr
mainEmpty = HExpr.Function "main" []
          $ HExpr.DoBlock [mkGetIO $ HExpr.AppE (HExpr.Var "val") $ HExpr.Tuple []]


genVArgCon arglen name ccname params base = getter where
    argVars    = map (("v" ++).show) [1..arglen]
    exprArgs   = map HExpr.Var argVars
    t          = foldl HExpr.AppE (HExpr.Var ccname) (map HExpr.Var params)
    selfVar    = HExpr.TypedP t $ HExpr.Var "self"
    exprVars   = selfVar : exprArgs
    getter     = HExpr.Function (mkTName arglen name) exprVars
               $ mkPure (foldl HExpr.AppE base exprArgs)


genVArgGetter arglen mname = getter where
    argVars    = map (("v" ++).show) [1..arglen]
    exprArgs   = map HExpr.Var argVars
    exprVars   = HExpr.Var "self" : exprArgs
    getterBase = HExpr.AppE (HExpr.Var $ mkFuncName mname)
               $ HExpr.AppE (HExpr.Var $ mkGetName $ mkCFName mname) (HExpr.Var "self")
    getter     = HExpr.Function (mkTName arglen mname) exprVars
               $ foldl HExpr.AppE getterBase exprArgs


genVArgGetterL arglen mname cfname = getter where
    argVars    = map (("v" ++).show) [1..arglen]
    exprArgs   = map HExpr.Var argVars
    t          = mkPure $ foldl HExpr.AppE (HExpr.Var cfname) (map HExpr.Var [])
    selfVar    = HExpr.TypedP t $ HExpr.Var "self"
    exprVars   = selfVar : exprArgs
    getterBase = (HExpr.Var $ mkFuncName mname)
    getter     = HExpr.Function (mkTName arglen mname) exprVars
               $ foldl HExpr.AppE getterBase exprArgs


-- generate declarations (imports, CF newtypes, THInstC)
genFuncDecl clsname name = do
    let vname  = mkVarName name
        cfName = mkCFName $ mangleName clsname vname

    GenState.addNewType      $ genCFDec clsname cfName
    GenState.addTHExpression $ genTHInstMem name cfName


typeMethodSelf cls inputs = nargs
    where (self:args) = inputs
          nparams     = map (LType.Var 0) (view LType.params cls)
          patbase     = LType.App 0 (LType.Con 0 [view LType.name cls]) nparams
          nself       = self & over LExpr.pat (\p -> LPat.Typed 0 p patbase)
          nargs       = nself:args


--genCon :: GenMonad m => LExpr -> Pass.Result m (HExpr, m0())
genCon dataName (LExpr.ConD _ conName fields) = do
    let fieldlen = length fields
        conMemName = Naming.mkMemName dataName conName
    expr  <- HExpr.Con conName <$> mapM genExpr fields
    let th =  GenState.addTHExpression (thRegisterCon dataName conName fieldlen [])
           *> GenState.addTHExpression (thClsCallInsts conMemName fieldlen 0)
           -- *> GenState.addTHExpression (thGenerateClsGetters conName)
    return (expr, th)


genExpr :: LExpr -> GenPass HExpr
genExpr ast = case ast of
    LExpr.Var      _ name                -> pure $ HExpr.Var $ mkVarName name
    LExpr.Con      _ name                -> pure $ HExpr.Var ("con" ++ mkConsName name)
    LExpr.Function _ path name
                     inputs output body  -> do
                                            cls <- GenState.getCls
                                            let clsName = if (null path)
                                                    then LType.getNameID cls
                                                    else (path!!0) -- FIXME[wd]: needs name resolver

                                                ninputs = inputs
                                                argNum     = length ninputs
                                                mname      = mangleName clsName $ mkVarName name
                                                vargGetter = genVArgGetter (argNum-1) mname
                                                cgetCName  = mkCGetCName (argNum-1)
                                                cgetName   = mkCGetName  (argNum-1)
                                                getNName   = mkTName (argNum-1) mname
                                                fname      = Naming.mkMemName clsName name

                                            when (length path > 1) $ Pass.fail "Complex method extension paths are not supported yet."

                                            --genFuncDecl clsName name

                                            --f  <-   HExpr.Assignment (HExpr.Var fname)
                                            --        <$> ( HExpr.AppE (HExpr.Var $ "defFunction" ++ show (argNum + 1))
                                            --              <$> ( HExpr.Lambda <$> (mapM genExpr ninputs)
                                            --                                 <*> (HExpr.DoBlock <$> ((emptyHExpr :) <$> genFuncBody body output))
                                            --                  )
                                            --            )

                                            f  <-   HExpr.Assignment (HExpr.Var fname)
                                                          <$> ( HExpr.Lambda <$> (mapM genExpr ninputs)
                                                                             <*> (HExpr.DoBlock <$> ((emptyHExpr :) <$> genFuncBody body output))
                                                              )

                                            GenState.addFunction f

                                            ---- GetN functions
                                            --GenState.addFunction vargGetter

                                            ---- TH snippets
                                            --GenState.addTHExpression $ genTHInst cgetCName getNName cgetName
                                            --GenState.addTHExpression $ thSelfTyped fname clsName

                                            GenState.addTHExpression $ thRegisterFunction fname argNum []
                                            GenState.addTHExpression $ thClsCallInsts fname argNum 0
                                            GenState.addTHExpression $ thRegisterMember name clsName fname

                                            return f

    LExpr.Lambda id inputs output body   -> do
                                            let fname      = Naming.mkLamName $ show id
                                                hName      = Naming.mkHandlerFuncName fname
                                                cfName     = mkCFLName fname
                                                argNum     = length inputs
                                                cgetCName  = mkCGetCName argNum
                                                cgetName   = mkCGetName  argNum
                                                getNName   = mkTName argNum fname
                                                vargGetter = genVArgGetterL argNum fname cfName

                                            GenState.addDataType $ HExpr.DataD cfName [] [HExpr.Con cfName []] [Deriving.Show]

                                            f  <-   HExpr.Assignment (HExpr.Var fname)
                                                    <$> ( HExpr.Lambda <$> (mapM genExpr inputs)
                                                                       <*> (HExpr.DoBlock <$> ((emptyHExpr :) <$> genFuncBody body output))
                                                        )
                                            GenState.addFunction f

                                            GenState.addTHExpression $ thRegisterFunction fname argNum []
                                            GenState.addTHExpression $ thClsCallInsts fname argNum 0

                                            --GenState.addFunction vargGetter
                                            --GenState.addTHExpression $ genTHInst cgetCName getNName cgetName

                                            return $ HExpr.Var hName

    LExpr.Arg _ pat _                    -> genPat pat

    LExpr.Import _ path target rename    -> do
                                            tname <- case target of
                                                LExpr.Con      _ tname -> pure tname
                                                LExpr.Var      _ tname -> pure tname
                                                LExpr.Wildcard _       -> Pass.fail "Wildcard imports are not supported yet."
                                                _                      -> Pass.fail "Internal error."
                                            case rename of
                                                Just _                 -> Pass.fail "Named imports are not supported yet."
                                                _                      -> pure ()

                                            return $ HExpr.Import False (["FlowboxM", "Libs"] ++ path ++ [tname]) Nothing where

    LExpr.Data _ cls cons classes methods -> do
                                           let name        = view LType.name   cls
                                               params      = view LType.params cls

                                           GenState.setCls cls

                                           consTuples <- mapM (genCon name) cons
                                           let consE  = map fst consTuples
                                               consTH = map snd consTuples

                                           let dt = HExpr.DataD name params consE stdDerivings
                                           GenState.addDataType dt

                                           sequence consTH

                                           GenState.addTHExpression $ thGenerateAccessors name
                                           GenState.addTHExpression $ thRegisterAccessors name
                                           GenState.addTHExpression $ thInstsAccessors name

                                           mapM_ genExpr methods

                                           return dt

    LExpr.Infix        _ name src dst        -> HExpr.Infix name <$> genExpr src <*> genExpr dst
    LExpr.Assignment   _ pat dst             -> HExpr.Arrow <$> genPat pat <*> genCallExpr dst
    LExpr.RecordUpdate _ src selectors expr  -> genExpr $ (setSteps sels) expr
                                                where setter sel exp val = flip (LExpr.App 0) [val]
                                                                         $ LExpr.Accessor 0 (Naming.mkSetName sel) exp
                                                      getter sel exp     = flip (LExpr.App 0) []
                                                                         $ LExpr.Accessor 0 sel exp
                                                      getSel sel           = foldl (flip($)) src (fmap getter (reverse sel))
                                                      setStep       (x:xs) = setter x (getSel xs)
                                                      setSteps args@(_:[]) = setStep args
                                                      setSteps args@(_:xs) = setSteps xs . setStep args
                                                      sels = reverse selectors

    LExpr.Lit          _ value               -> genLit value
    LExpr.Tuple        _ items               -> mkVal . HExpr.Tuple <$> mapM genExpr items -- zamiana na wywolanie funkcji!
    LExpr.Field        _ name fcls _         -> do
                                               cls <- GenState.getCls
                                               let clsName = view LType.name cls
                                               genTypedSafe HExpr.Typed fcls <*> pure (HExpr.Var $ Naming.mkPropertyName clsName name)
    --LExpr.App          _ src args             -> (liftM2 . foldl) HExpr.AppE (getN (length args) <$> genExpr src) (mapM genCallExpr args)
    LExpr.App          _ src args            -> HExpr.AppE <$> (HExpr.AppE (HExpr.Var "call") <$> genExpr src) <*> (mkRTuple <$> mapM genCallExpr args)
    LExpr.Accessor     _ name dst            -> HExpr.AppE <$> (pure $ mkMemberGetter name) <*> genExpr dst --(get0 <$> genExpr dst))
    LExpr.List         _ items               -> do
                                                let liftEl el = case el of
                                                        LExpr.RangeFromTo {} -> el
                                                        LExpr.RangeFrom   {} -> el
                                                        _                    -> LExpr.List 0 [el]
                                                    (arrMod, elmod) = if any isRange items
                                                        then (HExpr.AppE (HExpr.Var "concatPure"), liftEl)
                                                        else (Prelude.id, Prelude.id)

                                                mkVal . arrMod . HExpr.ListE <$> mapM (genExpr . elmod) items
    LExpr.RangeFromTo _ start end            -> HExpr.AppE . HExpr.AppE (HExpr.Var "rangeFromTo") <$> genExpr start <*> genExpr end
    LExpr.RangeFrom   _ start                -> HExpr.AppE (HExpr.Var "rangeFrom") <$> genExpr start
    LExpr.Native      _ segments             -> pure $ HExpr.Native (join "" $ map genNative segments)
    LExpr.Typed       _ cls expr             -> Pass.fail "Typing expressions is not supported yet." -- Potrzeba uzywac hacku: matchTypes (undefined :: m1(s1(Int)))  (val (5 :: Int))
    --x                                        -> logger error (show x) *> return HExpr.NOP
    where
        getN n = HExpr.AppE (HExpr.Var $ "call" ++ show n)
        get0   = getN (0::Int)

isRange e = case e of
    LExpr.RangeFromTo {} -> True
    LExpr.RangeFrom   {} -> True
    _                    -> False


genNative expr = case expr of
    LExpr.NativeCode _ code -> code
    LExpr.NativeVar  _ name -> mkVarName name

genCallExpr :: LExpr -> GenPass HExpr
genCallExpr e = trans <$> genExpr e where
    trans = case e of
        LExpr.App        {} -> id
        LExpr.Native     {} -> id
        LExpr.Assignment {} -> id
        LExpr.Lambda     {} -> id
        _                   -> id
        --_                   -> call0
    id     = Prelude.id
    call0  = HExpr.AppE (HExpr.Var "call0")
    ret    = HExpr.AppE $ HExpr.Var "return"

genFuncBody :: [LExpr] -> LType -> GenPass [HExpr]
genFuncBody exprs output = case exprs of
    []   -> pure []
    x:[] -> (:) <$> case x of
                      LExpr.Assignment _ _ dst -> (genTypedE output <*> genFuncTopLevelExpr x)
                      LExpr.Native     {}      -> genFuncTopLevelExpr x
                      _                        -> (genTypedE output <*> genFuncTopLevelExpr x) -- mkGetIO <$>
                <*> case x of
                      LExpr.Assignment _ _ dst -> (:[]) <$> (genTypedE output <*> pure (mkVal $ HExpr.Tuple [])) -- . mkGetIO
                      _                        -> pure []
    x:xs -> (:) <$> genFuncTopLevelExpr x <*> genFuncBody xs output


genFuncTopLevelExpr :: LExpr -> GenPass HExpr
genFuncTopLevelExpr expr = case expr of
    LExpr.RecordUpdate _ (LExpr.Var _ name) _ _ -> genFuncTopLevelExpr $ LExpr.Assignment 0 (LPat.Var 0 name) expr
    _                                           -> genCallExpr expr


genPat :: LPat.Pat -> GenPass HExpr
genPat p = case p of
    LPat.Var      _ name     -> return $ HExpr.Var (mkVarName name)
    LPat.Typed    _ pat cls  -> genTypedP cls <*> genPat pat
    LPat.Tuple    _ items    -> mkPure . HExpr.TupleP <$> mapM genPat items
    LPat.Lit      _ value    -> genLit value
    LPat.Wildcard _          -> return $ HExpr.WildP
    _ -> fail $ show p


genTypedE :: LType -> GenPass (HExpr -> HExpr)
genTypedE = genTyped HExpr.TypedE

genTypedP :: LType -> GenPass (HExpr -> HExpr)
genTypedP = genTyped HExpr.TypedP

genTyped :: (HExpr -> HExpr -> HExpr) -> LType -> GenPass (HExpr -> HExpr)
genTyped = genTypedProto False

genTypedSafe :: (HExpr -> HExpr -> HExpr) -> LType -> GenPass (HExpr -> HExpr)
genTypedSafe = genTypedProto True

genTypedProto :: Bool -> (HExpr -> HExpr -> HExpr) -> LType -> GenPass (HExpr -> HExpr)
genTypedProto safeTyping cls t = case t of
    LType.Unknown _          -> pure Prelude.id
    _                        -> cls <$> genType safeTyping t

genType :: Bool -> LType -> GenPass HExpr
genType safeTyping t = case t of
    LType.Var     _ name      -> return $ thandler (HExpr.Var  name)
    LType.Con     id segments -> return $ thandler (HExpr.ConE segments)

    LType.Tuple   _ items    -> HExpr.Tuple <$> mapM (genType safeTyping) items
    LType.App     _ src args -> (liftM2 . foldl) (HExpr.AppT) (genType safeTyping src) (mapM (genType safeTyping) args)
    LType.Unknown _          -> logger critical "Cannot generate code for unknown type" *> Pass.fail "Cannot generate code for unknown type"
    --_                        -> fail $ show t
    where mtype    = HExpr.VarT $ if safeTyping then "Pure" else "m_" ++ show (view LType.id t)
          stype    = HExpr.VarT $ if safeTyping then "Safe" else "s_" ++ show (view LType.id t)
          thandler = HExpr.AppT mtype . HExpr.AppT stype

genLit :: LLit.Lit -> GenPass HExpr
genLit lit = case lit of
    LLit.Integer _ str      -> mkLit "Int"    (HLit.Integer str)
    LLit.Float   _ str      -> mkLit "Double" (HLit.Float   str)
    LLit.String  _ str      -> mkLit "String" (HLit.String  str)
    LLit.Char    _ char     -> mkLit "Char"   (HLit.Char    char)
    --_ -> fail $ show lit
    where mkLit cons hast = return . mkVal $ HExpr.TypedE (HExpr.ConT cons) (HExpr.Lit hast)

