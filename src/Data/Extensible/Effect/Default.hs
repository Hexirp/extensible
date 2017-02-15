{-# LANGUAGE MultiParamTypeClasses, UndecidableInstances #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Extensible.Effect.Default
-- Copyright   :  (c) Fumiaki Kinoshita 2017
-- License     :  BSD3
--
-- Maintainer  :  Fumiaki Kinoshita <fumiexcel@gmail.com>
--
-- Default monad runners and 'MonadIO', 'MonadReader', 'MonadWriter',
-- 'MonadState', 'MonadError' instances
-----------------------------------------------------------------------------
module Data.Extensible.Effect.Default (
  ReaderDef
  , runReaderDef
  , StateDef
  , runStateDef
  , WriterDef
  , runWriterDef
  , MaybeDef
  , runMaybeDef
  , EitherDef
  , runEitherDef
) where
import Control.Monad.Skeleton
import Data.Extensible.Effect
import Data.Extensible.Internal
import Control.Monad.Except
import Control.Monad.Reader.Class
import Control.Monad.State.Strict
import Control.Monad.Writer.Class

instance Associate "IO" IO xs => MonadIO (Eff xs) where
  liftIO = liftEff (Proxy :: Proxy "IO")

instance Associate "Reader" ((->) r) xs => MonadReader r (Eff xs) where
  ask = liftEff (Proxy :: Proxy "Reader") ask
  local f = hoistEff (Proxy :: Proxy "Reader") (local f)
  reader f = liftEff (Proxy :: Proxy "Reader") (reader f)

instance Associate "State" (State s) xs => MonadState s (Eff xs) where
  get = liftEff (Proxy :: Proxy "State") get
  put = liftEff (Proxy :: Proxy "State") . put
  state = liftEff (Proxy :: Proxy "State") . state

instance (Monoid w, Associate "Writer" ((,) w) xs) => MonadWriter w (Eff xs) where
  writer (a, w) = liftEff (Proxy :: Proxy "Writer") (w, a)
  tell w = liftEff (Proxy :: Proxy "Writer") (w, ())
  listen = go mempty where
    go !w m = case unbone m of
      Return a -> return (a, w)
      Instruction i t :>>= k -> case compareMembership (association :: Membership xs ("Writer" ':> (,) w)) i of
        Left _ -> boned $ Instruction i t :>>= go w . k
        Right Refl -> let (w', a) = t in go (mappend w w') (k a)
  pass = go mempty where
    go w m = case unbone m of
      Return (a, f) -> writer (a, f w)
      Instruction i t :>>= k -> case compareMembership (association :: Membership xs ("Writer" ':> (,) w)) i of
        Left _ -> boned $ Instruction i t :>>= go w . k
        Right Refl -> let (w', a) = t in go (mappend w w') (k a)

instance (Associate "Either" (Either e) xs) => MonadError e (Eff xs) where
  throwError = liftEff (Proxy :: Proxy "Either") . Left
  catchError m0 handler = go m0 where
    go m = case unbone m of
      Return a -> return a
      Instruction i t :>>= k -> case compareMembership (association :: Membership xs ("Either" ':> Either e)) i of
        Left _ -> boned $ Instruction i t :>>= go . k
        Right Refl -> either handler (go . k) t

type ReaderDef r = "Reader" >: (->) r

runReaderDef :: Eff (ReaderDef r ': xs) a -> r -> Eff xs a
runReaderDef = runReaderEff
{-# INLINE runReaderDef #-}

type StateDef s = "State" >: State s

runStateDef :: Eff (StateDef s ': xs) a -> s -> Eff xs (a, s)
runStateDef = runStateEff
{-# INLINE runStateDef #-}

type WriterDef w = "Writer" >: (,) w

runWriterDef :: Monoid w => Eff (WriterDef w ': xs) a -> Eff xs (a, w)
runWriterDef = runWriterEff
{-# INLINE runWriterDef #-}

type MaybeDef = "Maybe" >: Maybe

runMaybeDef :: Eff (MaybeDef ': xs) a -> Eff xs (Maybe a)
runMaybeDef = runMaybeEff
{-# INLINE runMaybeDef #-}

type EitherDef e = "Either" >: Either e

runEitherDef :: Eff (EitherDef e ': xs) a -> Eff xs (Either e a)
runEitherDef = runEitherEff
{-# INLINE runEitherDef #-}
