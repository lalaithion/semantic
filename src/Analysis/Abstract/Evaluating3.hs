{-# LANGUAGE ConstraintKinds, DataKinds, ScopedTypeVariables, TypeApplications, TypeFamilies, TypeOperators, MultiParamTypeClasses #-}
module Analysis.Abstract.Evaluating3 where

import Control.Monad.Effect
import Control.Monad.Effect.Fail
import Control.Monad.Effect.Reader
import Control.Monad.Effect.Store2
import Control.Monad.Effect.State
import Data.Abstract.Address
import Data.Abstract.Environment
import Data.Abstract.Linker
import Data.Abstract.FreeVariables
import Data.Abstract.Eval3
import Data.Abstract.Store
import Data.Abstract.Value
import Data.Abstract.Live
import Data.Function (fix)
import Data.Functor.Foldable (Base, Recursive(..))
import qualified Data.Map as Map
import Data.Semigroup
import Prelude hiding (fail)
import Data.Blob
import System.FilePath.Posix

-- | The effects necessary for concrete interpretation.
type Evaluating term v
  = '[ Fail                                  -- For 'MonadFail'.
     , Store2 v                              -- For 'MonadStore'.
     , State (Environment (LocationFor v) v) -- Environment State
     , Eval (Base term) term
     ]

type Evaluating' term v
  = '[ Fail                                   -- For 'MonadFail'.
     , Store2 v       -- For 'MonadStore'.
     , Reader (Environment (LocationFor v) v) -- Local environment
     , State  (Environment (LocationFor v) v) -- Global environment
     ]


-- | Evaluate a term to a value.
evaluate :: forall term v. ( Ord v
           , Ord (LocationFor v) -- For 'MonadStore'
           , Recursive term
           , Evaluatable '[] (Base term) term (Either Prelude.String v)
           , Evaluatable (Evaluating term v) (Base term) term v
           )
         => term
         -> Either Prelude.String v
evaluate = run
  . runEval
  . fmap fst
  . flip runState mempty
  . fmap fst
  . flip runState mempty
  . runFail
  . (fix (const (eval . project :: term -> Eff (Evaluating term v) v)))
