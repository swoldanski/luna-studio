---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts, NoMonomorphismRestriction, ConstraintKinds, TupleSections #-}

module Flowbox.Luna.Passes.Transform.HAST.HASTGen.HASTGen where

import qualified Flowbox.Prelude                                     as Prelude
import           Flowbox.Prelude                                     hiding (error, id, mod)
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
import           Flowbox.Luna.Passes.Pass                              (PassMonad)
import           Flowbox.System.Log.Logger                             
import           Flowbox.Luna.Passes.Transform.HAST.HASTGen.Utils      
import           Data.String.Utils                                     (join)
import qualified Data.Set                                            as Set

import           Control.Monad.State                                 hiding (mapM, mapM_, join)
import           Control.Applicative                                   

type GenMonad m = PassMonad GenState m

type HExpr   = HExpr.Expr
type LExpr   = LExpr.Expr
type LType   = LType.Type
type LModule = LModule.Module


logger :: Logger
logger = getLogger "Flowbox.Luna.Passes.Transform.HAST.HASTGen.HASTGen"


run :: PassMonad s m => LModule -> Pool -> Pass.Result m HExpr
run = (Pass.run_ (Pass.Info "HASTGen") GenState.empty) .: genModule


genModule :: GenMonad m => LModule -> Pool -> Pass.Result m HExpr
genModule lmod@(LModule.Module _ cls imports classes _ methods _) fpool = do 
    let (LType.Module _ path) = cls
        fnames  = Set.toList $ Pool.names fpool
        mod     = HModule.addImport ["FlowboxM", "Luna", "Helpers", "Core"]
                $ HModule.addExt HExtension.TemplateHaskell
                $ HModule.addExt HExtension.MultiParamTypeClasses
                $ HModule.addExt HExtension.FlexibleInstances
                $ HModule.addExt HExtension.UndecidableInstances
                $ HModule.addExt HExtension.ScopedTypeVariables
                $ HModule.addExt HExtension.NoMonomorphismRestriction
                $ HModule.addExt HExtension.RebindableSyntax 
                $ HModule.mk path
        name    = last path
        modcls  = LModule.mkClass lmod
        modclss = classes ++ [modcls]

    GenState.setModule mod

    -- add all FC imports
    mapM_ (GenState.addImport . genFCImport) fnames

    mapM_ genExpr modclss
    mapM_ (genExpr >=> GenState.addImport) imports
    when (name == "Main") $ do
        let funcnames = map LExpr.name methods
        if not $ "main" `elem` funcnames
            then logger warning "No 'main' function defined."
            else GenState.addFunction mainf
    GenState.getModule


mainf :: HExpr
mainf = HExpr.Function "main" [] $
        HExpr.DoBlock [   HExpr.Arrow (HExpr.Var "m")
                        $ HExpr.AppE (HExpr.Var "get0") 
                        $ HExpr.Var "con_Main"
                      ,   HExpr.AppE (HExpr.Var "get0") 
                        $ HExpr.AppE (HExpr.Var "_main")
                        $ HExpr.Var "m"
                      ] 


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
    t          = foldl HExpr.AppE (HExpr.Var cfname) (map HExpr.Var [])
    selfVar    = HExpr.TypedP t $ HExpr.Var "self"
    exprVars   = selfVar : exprArgs
    getterBase = (HExpr.Var $ mkFuncName mname)
    getter     = HExpr.Function (mkTName arglen mname) exprVars
               $ foldl HExpr.AppE getterBase exprArgs


-- generate declarations (imports, CF newtypes, THInstC)
genFuncDecl clsname name = do
    let vname  = mkVarName name
        cfName = mkCFName $ mangleName clsname vname
        fcName = mkFCName vname

    --GenState.addImport       $ genFCImport vname
    GenState.addNewType      $ genCFDec clsname cfName
    GenState.addTHExpression $ genTHInstC fcName cfName vname

genExpr :: GenMonad m => LExpr -> Pass.Result m HExpr
genExpr ast = case ast of
    LExpr.Var      _ name                -> pure $ HExpr.Var $ mkVarName name
    LExpr.Con      _ name                -> pure $ HExpr.Var ("con" ++ mkConsName name)
    LExpr.Function _ path name  
                     inputs output body  -> do
                                            clsName <- GenState.getClsName
                                            let clsName2 = if (null path) 
                                                    then clsName
                                                    else (path!!0)
                                                arglen     = length inputs - 1
                                                mname      = mangleName clsName2 $ mkVarName name
                                                vargGetter = genVArgGetter arglen mname
                                                cgetCName  = mkCGetCName arglen
                                                cgetName   = mkCGetName  arglen
                                                getNName   = mkTName arglen mname
                                                fname      = mkFuncName mname

                                            when (length path > 1) $ Pass.fail "Complex method extension paths are not supported yet."
                                            if (null path) then return ()
                                                else genFuncDecl (path!!0) name

                                            f  <-   HExpr.Assignment (HExpr.Var fname) 
                                                    <$> ( HExpr.AppE (HExpr.Var $ "defFunction" ++ show (arglen + 1))
                                                          <$> ( HExpr.Lambda <$> (mapM genExpr inputs)
                                                                             <*> (HExpr.DoBlock <$> ((emptyHExpr :) <$> genFuncBody body output))
                                                              )
                                                        )

                                            GenState.addFunction f
                                           
                                            -- GetN functions
                                            GenState.addFunction vargGetter
                                            
                                            -- TH snippets
                                            GenState.addTHExpression $ genTHInst cgetCName getNName cgetName
                                             
                                            return f

    LExpr.Lambda id inputs output body   -> do
                                            let mname      = mkLamName $ show id
                                                fname      = mkFuncName mname
                                                cfName     = mkCFLName mname
                                                arglen     = length inputs - 1
                                                cgetCName  = mkCGetCName arglen
                                                cgetName   = mkCGetName  arglen
                                                getNName   = mkTName arglen mname
                                                vargGetter = genVArgGetterL arglen mname cfName

                                            GenState.addDataType $ HExpr.DataD cfName [] [HExpr.Con cfName []] ["Show"]

                                            f  <-   HExpr.Assignment (HExpr.Var fname) 
                                                    <$> ( HExpr.AppE (HExpr.Var $ "defFunction" ++ show (arglen + 1))
                                                          <$> ( HExpr.Lambda <$> (mapM genExpr inputs)
                                                                             <*> (HExpr.DoBlock <$> ((emptyHExpr :) <$> genFuncBody body output))
                                                              )
                                                        )
                                            GenState.addFunction f
                                            GenState.addFunction vargGetter
                                            GenState.addTHExpression $ genTHInst cgetCName getNName cgetName

                                            return $ mkPure $ HExpr.Var cfName

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
                                              
    LExpr.Class _ cls _ fields methods   -> do 
                                            let name        = LType.name   cls
                                                params      = LType.params cls
                                                fieldNames  = map LExpr.name fields
                                                fieldlen    = length fields
                                                funcNames   = map LExpr.name methods 
                                                memberNames = fieldNames ++ funcNames
                                                ccname      = mkCCName name
                                            
                                            GenState.setClsName name
                                            
                                            -- DataType
                                            cons   <- HExpr.Con name <$> mapM genExpr fields
                                            let dt = HExpr.DataD name params [cons] ["Show"]
                                            GenState.addDataType dt


                                            mapM_ (genFuncDecl name) memberNames

                                            mapM_ genExpr methods

                                            -- CONSTRUCTORS --

                                            -- CC type constructor
                                            let con = genCCDec ccname
                                            GenState.addDataType con

                                            -- constructor function
                                            GenState.addFunction $ genCon name ccname

                                            let test   = genVArgCon fieldlen name ccname [] (HExpr.ConE [name])
                                            GenState.addFunction $ test

                                            -- Constructor TH snippet
                                            let arglen    = fieldlen
                                                cgetCName = mkCGetCName arglen
                                                cgetName  = mkCGetName  arglen
                                                getNName  = mkTName arglen name
                                            GenState.addTHExpression $ genTHInst cgetCName getNName cgetName

                                              
                                            return dt

    LExpr.Infix       _ name src dst      -> HExpr.Infix name <$> genExpr src <*> genExpr dst
    LExpr.Assignment  _ pat dst           -> HExpr.Arrow <$> genPat pat <*> genCallExpr dst
    LExpr.Lit         _ value             -> genLit value
    LExpr.Tuple       _ items             -> mkPure . HExpr.Tuple <$> mapM genExpr items -- zamiana na wywolanie funkcji!
    LExpr.Field       _ name cls _        -> genTyped HExpr.Typed cls <*> pure (HExpr.Var $ mkFieldName name)
    LExpr.App         _ src args          -> (liftM2 . foldl) HExpr.AppE (getN (length args) <$> genExpr src) (mapM genCallExpr args)
    LExpr.Accessor    _ src dst           -> (HExpr.AppE <$> (genExpr dst) <*> (get0 <$> genExpr src))
    LExpr.List        _ items             -> do
                                             let liftEl el = case el of
                                                     LExpr.RangeFromTo {} -> el
                                                     LExpr.RangeFrom   {} -> el
                                                     _                    -> LExpr.List 0 [el]
                                                 (arrMod, elmod) = if any isRange items 
                                                     then (HExpr.AppE (HExpr.Var "concatPure"), liftEl)
                                                     else (Prelude.id, Prelude.id)
                         
                                             mkPure . arrMod . HExpr.ListE <$> mapM (genExpr . elmod) items
    LExpr.RangeFromTo _ start end         -> HExpr.AppE . HExpr.AppE (HExpr.Var "rangeFromTo") <$> genExpr start <*> genExpr end
    LExpr.RangeFrom   _ start             -> HExpr.AppE (HExpr.Var "rangeFrom") <$> genExpr start 
    LExpr.Native      _ segments          -> pure $ HExpr.Native (join "" $ map genNative segments)
    --LExpr.Native     _ segments          -> pure $ HExpr.Native code
    --_                                    -> fail $ show ast
    where
        getN n = HExpr.AppE (HExpr.Var $ "get" ++ show n)
        get0   = getN (0::Int)

isRange e = case e of
    LExpr.RangeFromTo {} -> True
    LExpr.RangeFrom   {} -> True
    _                    -> False


genNative expr = case expr of
    LExpr.NativeCode _ code -> code
    LExpr.NativeVar  _ name -> mkVarName name

genCallExpr :: GenMonad m => LExpr -> Pass.Result m HExpr
genCallExpr e = trans <$> genExpr e where
    trans = case e of
        LExpr.App        {} -> id
        LExpr.Native     {} -> id
        LExpr.Assignment {} -> id
        LExpr.Lambda     {} -> id
        _                   -> get0
    id     = Prelude.id
    getN n = HExpr.AppE (HExpr.Var $ "get" ++ show n)
    get0   = getN (0::Int)
    ret    = HExpr.AppE $ HExpr.Var "return"

genFuncBody :: GenMonad m => [LExpr] -> LType -> Pass.Result m [HExpr]
genFuncBody exprs output = case exprs of
    []   -> pure []
    x:[] -> liftM (:[]) $ genTyped HExpr.Typed output <*> case x of
            LExpr.Assignment _ _ dst -> mkGetIO <$> genCallExpr dst 
            LExpr.Native     {}      -> genCallExpr x
            _                        -> mkGetIO <$> genCallExpr x 
    x:xs -> (:) <$> genCallExpr x <*> genFuncBody xs output


genPat :: GenMonad m => LPat.Pat -> Pass.Result m HExpr
genPat p = case p of
    LPat.Var     _ name     -> return $ HExpr.Var (mkVarName name)
    LPat.Typed   _ pat cls  -> genTyped HExpr.TypedP cls <*> genPat pat
    LPat.Tuple   _ items    -> mkPure . HExpr.TupleP <$> mapM genPat items
                                   

genTyped :: GenMonad m => (HExpr -> HExpr -> HExpr) -> LType -> Pass.Result m (HExpr -> HExpr)
genTyped cls t = case t of
    LType.Unknown _          -> pure Prelude.id
    _                        -> cls <$> genType t

genType :: GenMonad m => LType -> Pass.Result m HExpr
genType t = case t of
    LType.Var     _ name     -> return $ HExpr.Var (name)
    LType.Con     _ segments -> return $ HExpr.AppT (HExpr.ConT "Pure") (HExpr.ConE segments)
    LType.Tuple   _ items    -> HExpr.Tuple <$> mapM genType items
    LType.App     _ src args -> (liftM2 . foldl) (HExpr.AppT) (genType src) (mapM genType args)
    LType.Unknown _          -> logger emergency "Cannot generate code for unknown type" *> Pass.fail "Cannot generate code for unknown type"
    --_                        -> fail $ show t
    --HExpr.AppT <$> genType src <*> genType (args !! 0)

genLit :: GenMonad m => LLit.Lit -> Pass.Result m HExpr
genLit lit = case lit of
    LLit.Integer _ str      -> mkLit "Int"    (HLit.Integer str)
    LLit.String  _ str      -> mkLit "String" (HLit.String str)
    --_ -> fail $ show lit
    where mkLit cons hast = return . mkPure $ HExpr.TypedE (HExpr.ConT cons) (HExpr.Lit hast)

