module Base
  ( module Test.Tasty,
    module Test.Tasty.HUnit,
    module Juvix.Prelude,
    module Base,
  )
where

import Control.Monad.Extra as Monad
import Data.Algorithm.Diff
import Data.Algorithm.DiffOutput
import Juvix.Prelude
import System.Environment (lookupEnv)
import Test.Tasty
import Test.Tasty.HUnit
import Text.Show.Pretty hiding (Html)

data AssertionDescr
  = Single Assertion
  | Steps ((String -> IO ()) -> Assertion)

data TestDescr = TestDescr
  { _testName :: String,
    _testRoot :: FilePath,
    -- | relative to root
    _testAssertion :: AssertionDescr
  }

newtype WASMInfo = WASMInfo
  { _wasmInfoActual :: FilePath -> IO Text
  }

makeLenses ''TestDescr

data StdlibMode = StdlibInclude | StdlibExclude
  deriving stock (Show, Eq)

data CompileMode = WASI StdlibMode | WASM WASMInfo

mkTest :: TestDescr -> TestTree
mkTest TestDescr {..} = case _testAssertion of
  Single assertion -> testCase _testName $ withCurrentDirectory _testRoot assertion
  Steps steps -> testCaseSteps _testName (withCurrentDirectory _testRoot . steps)

assertEqDiff :: (Eq a, Show a) => String -> a -> a -> Assertion
assertEqDiff msg a b
  | a == b = return ()
  | otherwise = do
      putStrLn (pack $ ppDiff (getGroupedDiff pa pb))
      putStrLn "End diff"
      Monad.fail msg
  where
    pa = lines $ ppShow a
    pb = lines $ ppShow b

assertCmdExists :: FilePath -> Assertion
assertCmdExists cmd =
  assertBool ("Command: " <> cmd <> " is not present on $PATH")
    . isJust
    =<< findExecutable cmd

assertEnvVar :: String -> String -> IO String
assertEnvVar msg varName = fromMaybeM (assertFailure msg) (lookupEnv varName)
