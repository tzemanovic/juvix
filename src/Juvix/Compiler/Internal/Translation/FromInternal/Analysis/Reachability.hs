module Juvix.Compiler.Internal.Translation.FromInternal.Analysis.Reachability where

import Juvix.Compiler.Abstract.Data.NameDependencyInfo
import Juvix.Compiler.Internal.Language
import Juvix.Compiler.Internal.Translation.FromAbstract.Data.Context
-- import Juvix.Compiler.Internal.Translation.FromInternal.Analysis.TypeChecking.Data.Context qualified as MicroTyped
import Juvix.Compiler.Internal.Translation.FromInternal.Analysis.ArityChecking qualified as MicroArity
import Juvix.Compiler.Internal.Translation.FromInternal.Analysis.TypeChecking.Data.Context qualified as MicroTyped
import Juvix.Prelude

filterUnreachable :: MicroTyped.InternalTypedResult -> MicroTyped.InternalTypedResult
filterUnreachable r = r {MicroTyped._resultModules = modules'}
  where
    depInfo = r ^. (MicroTyped.resultInternalArityResult . MicroArity.resultInternalResult . resultDepInfo)
    modules = r ^. MicroTyped.resultModules
    modules' = run $ runReader depInfo (mapM goModule modules)

returnIfReachable :: Member (Reader NameDependencyInfo) r => Name -> a -> Sem r (Maybe a)
returnIfReachable n a = do
  depInfo <- ask
  return $ if isReachable depInfo n then Just a else Nothing

goModule :: Member (Reader NameDependencyInfo) r => Module -> Sem r Module
goModule m = do
  stmts <- mapM goStatement (body ^. moduleStatements)
  return m {_moduleBody = body {_moduleStatements = catMaybes stmts}}
  where
    body = m ^. moduleBody

goStatement :: Member (Reader NameDependencyInfo) r => Statement -> Sem r (Maybe Statement)
goStatement s = case s of
  StatementInductive i -> returnIfReachable (i ^. inductiveName) s
  StatementFunction f -> returnIfReachable (f ^. funDefName) s
  StatementForeign {} -> return (Just s)
  StatementAxiom ax -> returnIfReachable (ax ^. axiomName) s
  StatementInclude i -> do
    m <- goModule (i ^. includeModule)
    return (Just (StatementInclude i {_includeModule = m}))
