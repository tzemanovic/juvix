module Juvix.Compiler.Internal.Language
  ( module Juvix.Compiler.Internal.Language,
    module Juvix.Compiler.Abstract.Data.Name,
    module Juvix.Data.WithLoc,
    module Juvix.Data.IsImplicit,
    module Juvix.Compiler.Concrete.Data.Literal,
    module Juvix.Data.Universe,
    module Juvix.Data.Hole,
    module Juvix.Data.Wildcard,
    module Juvix.Compiler.Concrete.Data.Builtins,
  )
where

import Juvix.Compiler.Abstract.Data.Name
import Juvix.Compiler.Concrete.Data.Builtins
import Juvix.Compiler.Concrete.Data.Literal
import Juvix.Data.Hole
import Juvix.Data.IsImplicit
import Juvix.Data.Universe hiding (smallUniverse)
import Juvix.Data.Wildcard
import Juvix.Data.WithLoc
import Juvix.Prelude

data Module = Module
  { _moduleName :: Name,
    _moduleExamples :: [Example],
    _moduleBody :: ModuleBody
  }

newtype Include = Include
  { _includeModule :: Module
  }

newtype ModuleBody = ModuleBody
  { _moduleStatements :: [Statement]
  }

data Statement
  = StatementInductive InductiveDef
  | StatementFunction FunctionDef
  | StatementForeign ForeignBlock
  | StatementAxiom AxiomDef
  | StatementInclude Include

data AxiomDef = AxiomDef
  { _axiomName :: AxiomName,
    _axiomBuiltin :: Maybe BuiltinAxiom,
    _axiomType :: Expression
  }

data FunctionDef = FunctionDef
  { _funDefName :: FunctionName,
    _funDefType :: Expression,
    _funDefExamples :: [Example],
    _funDefClauses :: NonEmpty FunctionClause,
    _funDefBuiltin :: Maybe BuiltinFunction
  }

data FunctionClause = FunctionClause
  { _clauseName :: FunctionName,
    _clausePatterns :: [PatternArg],
    _clauseBody :: Expression
  }

data Iden
  = IdenFunction Name
  | IdenConstructor Name
  | IdenVar VarName
  | IdenAxiom Name
  | IdenInductive Name
  deriving stock (Eq, Generic)

getName :: Iden -> Name
getName = \case
  IdenFunction n -> n
  IdenConstructor n -> n
  IdenVar n -> n
  IdenAxiom n -> n
  IdenInductive n -> n

instance Hashable Iden

data TypedExpression = TypedExpression
  { _typedType :: Expression,
    _typedExpression :: Expression
  }

data Expression
  = ExpressionIden Iden
  | ExpressionApplication Application
  | ExpressionFunction Function
  | ExpressionLiteral LiteralLoc
  | ExpressionHole Hole
  | ExpressionUniverse SmallUniverse
  | ExpressionLambda Lambda
  deriving stock (Eq, Generic)

instance Hashable Expression

data Example = Example
  { _exampleId :: NameId,
    _exampleExpression :: Expression
  }

data Lambda = Lambda
  { _lambdaVar :: VarName,
    _lambdaVarType :: Expression,
    _lambdaBody :: Expression
  }
  deriving stock (Eq, Generic)

instance Hashable Lambda

data Application = Application
  { _appLeft :: Expression,
    _appRight :: Expression,
    _appImplicit :: IsImplicit
  }

-- TODO: Eq and Hashable instances ignore the _appImplicit field
--  to workaround a crash in Micro->Mono translation when looking up
-- a concrete type.
instance Eq Application where
  (Application l r _) == (Application l' r' _) = (l == l') && (r == r')

instance Hashable Application where
  hashWithSalt salt (Application l r _) = hashWithSalt salt (l, r)

-- | Fully applied constructor in a pattern.
data ConstructorApp = ConstructorApp
  { _constrAppConstructor :: Name,
    _constrAppParameters :: [PatternArg]
  }

data PatternArg = PatternArg
  { _patternArgIsImplicit :: IsImplicit,
    _patternArgPattern :: Pattern
  }

data Pattern
  = PatternVariable VarName
  | PatternConstructorApp ConstructorApp
  | PatternWildcard Wildcard

newtype InductiveParameter = InductiveParameter
  { _inductiveParamName :: VarName
  }
  deriving stock (Eq)

data InductiveDef = InductiveDef
  { _inductiveName :: InductiveName,
    _inductiveBuiltin :: Maybe BuiltinInductive,
    _inductiveExamples :: [Example],
    _inductiveParameters :: [InductiveParameter],
    _inductiveConstructors :: [InductiveConstructorDef],
    _inductivePositive :: Bool
  }

data InductiveConstructorDef = InductiveConstructorDef
  { _inductiveConstructorName :: ConstrName,
    _inductiveConstructorParameters :: [Expression],
    _inductiveConstructorExamples :: [Example],
    _inductiveConstructorReturnType :: Expression
  }

data FunctionParameter = FunctionParameter
  { _paramName :: Maybe VarName,
    _paramImplicit :: IsImplicit,
    _paramType :: Expression
  }
  deriving stock (Eq, Generic)

instance Hashable FunctionParameter

data Function = Function
  { _functionLeft :: FunctionParameter,
    _functionRight :: Expression
  }
  deriving stock (Eq, Generic)

instance Hashable Function

makeLenses ''Module
makeLenses ''Example
makeLenses ''PatternArg
makeLenses ''Include
makeLenses ''FunctionDef
makeLenses ''FunctionClause
makeLenses ''InductiveDef
makeLenses ''AxiomDef
makeLenses ''ModuleBody
makeLenses ''Application
makeLenses ''TypedExpression
makeLenses ''Function
makeLenses ''Lambda
makeLenses ''FunctionParameter
makeLenses ''InductiveParameter
makeLenses ''InductiveConstructorDef
makeLenses ''ConstructorApp

instance HasAtomicity Application where
  atomicity = const (Aggregate appFixity)

instance HasAtomicity Lambda where
  atomicity = const Atom

instance HasAtomicity Expression where
  atomicity e = case e of
    ExpressionIden {} -> Atom
    ExpressionApplication a -> atomicity a
    ExpressionLiteral l -> atomicity l
    ExpressionHole {} -> Atom
    ExpressionUniverse u -> atomicity u
    ExpressionFunction f -> atomicity f
    ExpressionLambda l -> atomicity l

instance HasAtomicity Function where
  atomicity = const (Aggregate funFixity)

instance HasAtomicity ConstructorApp where
  atomicity (ConstructorApp _ args)
    | null args = Atom
    | otherwise = Aggregate appFixity

instance HasAtomicity PatternArg where
  atomicity p
    | Implicit <- p ^. patternArgIsImplicit = Atom
    | otherwise = atomicity (p ^. patternArgPattern)

instance HasAtomicity Pattern where
  atomicity p = case p of
    PatternConstructorApp a -> atomicity a
    PatternVariable {} -> Atom
    PatternWildcard {} -> Atom

instance HasLoc InductiveParameter where
  getLoc (InductiveParameter n) = getLoc n

instance HasLoc FunctionParameter where
  getLoc f = v (getLoc (f ^. paramType))
    where
      v = case getLoc <$> f ^. paramName of
        Nothing -> id
        Just i -> (i <>)

instance HasLoc Function where
  getLoc (Function l r) = getLoc l <> getLoc r

instance HasLoc Application where
  getLoc (Application l r _) = getLoc l <> getLoc r

instance HasLoc Lambda where
  getLoc l = getLoc (l ^. lambdaVar) <> getLoc (l ^. lambdaBody)

instance HasLoc Expression where
  getLoc = \case
    ExpressionIden i -> getLoc i
    ExpressionApplication a -> getLoc a
    ExpressionLiteral l -> getLoc l
    ExpressionHole h -> getLoc h
    ExpressionUniverse u -> getLoc u
    ExpressionFunction u -> getLoc u
    ExpressionLambda l -> getLoc l

instance HasLoc Iden where
  getLoc = \case
    IdenFunction f -> getLoc f
    IdenConstructor c -> getLoc c
    IdenVar v -> getLoc v
    IdenAxiom a -> getLoc a
    IdenInductive a -> getLoc a

instance HasLoc Pattern where
  getLoc = \case
    PatternVariable v -> getLoc v
    PatternConstructorApp a -> getLoc a
    PatternWildcard i -> getLoc i

instance HasLoc PatternArg where
  getLoc = getLoc . (^. patternArgPattern)

instance HasLoc ConstructorApp where
  getLoc (ConstructorApp c ps) =
    case last <$> nonEmpty ps of
      Just p -> getLoc c <> getLoc p
      Nothing -> getLoc c
