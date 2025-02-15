-- | Generic class of errors generated by the juvix compiler. Inspired by
-- Control.Exception
module Juvix.Data.Error
  ( module Juvix.Data.Error,
    module Juvix.Data.Error.GenericError,
  )
where

import Juvix.Data.Error.GenericError
import Juvix.Prelude.Base

data JuvixError
  = forall a. (ToGenericError a, Typeable a) => JuvixError a

instance ToGenericError JuvixError where
  genericError (JuvixError e) = genericError e

fromJuvixError :: Typeable a => JuvixError -> Maybe a
fromJuvixError (JuvixError e) = cast e
