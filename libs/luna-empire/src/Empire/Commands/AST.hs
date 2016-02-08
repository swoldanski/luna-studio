{-# LANGUAGE FlexibleContexts #-}

module Empire.Commands.AST where

import           Prologue
import           Control.Monad.State
import           Control.Monad.Error          (throwError)
import           Data.Record                  (ANY (..), caseTest, match)
import           Data.Prop                    (prop)

import           Empire.Empire
import           Empire.API.Data.DefaultValue (PortDefault)
import           Empire.API.Data.NodeMeta     (NodeMeta)
import           Empire.Data.AST              (AST, NodeRef)

import           Empire.ASTOp                 (runASTOp)
import qualified Empire.ASTOps.Builder        as ASTBuilder
import qualified Empire.ASTOps.Parse          as Parser
import qualified Empire.ASTOps.Print          as Printer
import           Empire.ASTOps.Remove         (safeRemove)

import qualified Luna.Syntax.Builder          as Builder
import           Luna.Syntax.Builder          (Meta (..), source)

meta :: Meta NodeMeta
meta = Meta

addNode :: String -> String -> Command AST (NodeRef)
addNode name expr = runASTOp $ Parser.parseFragment expr >>= ASTBuilder.unifyWithName name

addDefault :: PortDefault -> Command AST (NodeRef)
addDefault val = runASTOp $ Parser.parsePortDefault val

readMeta :: NodeRef -> Command AST (Maybe NodeMeta)
readMeta ref = runASTOp $ view (prop meta) <$> Builder.read ref

writeMeta :: NodeRef -> Maybe NodeMeta -> Command AST ()
writeMeta ref newMeta = runASTOp $ do
    node <- Builder.read ref
    Builder.write ref (node & prop meta .~ newMeta)

renameVar :: NodeRef -> String -> Command AST ()
renameVar = runASTOp .: ASTBuilder.renameVar

removeSubtree :: NodeRef -> Command AST ()
removeSubtree = runASTOp . safeRemove

printExpression :: NodeRef -> Command AST String
printExpression = runASTOp . Printer.printExpression

applyFunction :: NodeRef -> NodeRef -> Int -> Command AST (NodeRef)
applyFunction = runASTOp .:. ASTBuilder.applyFunction

unapplyArgument :: NodeRef -> Int -> Command AST (NodeRef)
unapplyArgument = runASTOp .: ASTBuilder.removeArg

makeAccessor :: NodeRef -> NodeRef -> Command AST (NodeRef)
makeAccessor = runASTOp .: ASTBuilder.makeAccessor

removeAccessor :: NodeRef -> Command AST (NodeRef)
removeAccessor = runASTOp . ASTBuilder.unAcc

getTargetNode :: NodeRef -> Command AST (NodeRef)
getTargetNode nodeRef = runASTOp $ Builder.read nodeRef
                               >>= return . view ASTBuilder.rightUnifyOperand
                               >>= Builder.follow source

getVarNode :: NodeRef -> Command AST (NodeRef)
getVarNode nodeRef = runASTOp $ Builder.read nodeRef
                            >>= return . view ASTBuilder.leftUnifyOperand
                            >>= Builder.follow source

replaceTargetNode :: NodeRef -> NodeRef -> Command AST ()
replaceTargetNode unifyNodeId newTargetId = runASTOp $ do
    Builder.reconnect unifyNodeId ASTBuilder.rightUnifyOperand newTargetId
    return ()
