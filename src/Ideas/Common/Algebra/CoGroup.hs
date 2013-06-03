-----------------------------------------------------------------------------
-- Copyright 2013, Open Universiteit Nederland. This file is distributed
-- under the terms of the GNU General Public License. For more information,
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Ideas.Common.Algebra.CoGroup
   ( CoMonoid(..), CoGroup(..), CoMonoidZero(..)
   , associativeList
   ) where

import Control.Applicative
import Control.Arrow
import Data.Maybe
import Ideas.Common.Algebra.Group
import Ideas.Common.Classes
import qualified Data.Set as S
--import qualified Data.Map as M
--import qualified Data.Sequence as Q

class CoMonoid a where
   isEmpty  :: a -> Bool
   isAppend :: a -> Maybe (a, a)

class CoMonoid a => CoGroup a where
   isInverse   :: a -> Maybe a
   isAppendInv :: a -> Maybe (a, a)
   -- default definition
   isAppendInv = const Nothing

class CoMonoid a => CoMonoidZero a where
   isMonoidZero :: a -> Bool

fromSemiGroup :: (CoMonoid a, Monoid b) => (a -> b) -> a -> b
fromSemiGroup f = rec
 where
   rec a = maybe (f a) make (isAppend a)
   make (x, y) = rec x <> rec y
{-
fromMonoid :: (CoMonoid a, Monoid b) => (a -> b) -> a -> b
fromMonoid f = fromSemiGroup $ \a ->
   if isEmpty a then mempty else f a

fromGroup :: (CoGroup a, Group b) => (a -> b) -> a -> b
fromGroup f = rec
 where
   rec = fromMonoid $ \a ->
      case isInverse a of
         Just x  -> inverse (rec x)
         Nothing ->
            case isAppendInverse a of
               Just (x, y) -> rec x <>- rec y
               Nothing     -> f a

fromMonoidZero :: (CoMonoidZero a, MonoidZero b) => (a -> b) -> a -> b
fromMonoidZero f = fromMonoid $ \a ->
   if isZero a then zero else f a

----------------------
-}
associativeList :: CoMonoid a => a -> [a]
associativeList = fromSemiGroup singleton
{-
monoidList :: CoMonoid a => a -> [a]
monoidList = fromMonoid singleton

-- For commutative (and associative) monoids
monoidMultiSet :: (CoMonoid a, Ord a) => a -> MultiSet a
monoidMultiSet = fromMonoid singleton

-- For associative, commutative, idempotent (ACI) monoids
monoidSet :: (CoMonoid a, Ord a) => a -> S.Set a
monoidSet = fromMonoid singleton

groupSequence :: (CoGroup a, Eq a) => a -> GroupSequence a
groupSequence = fromGroup singleton

abelianMultiSet :: (CoGroup a, Ord a) => a -> MultiSet a
abelianMultiSet = fromGroup singleton

monoidZeroList :: CoMonoidZero a => a -> WithZero [a]
monoidZeroList = fromMonoidZero (pure . singleton)

----------------------

newtype MultiSet a = MS (M.Map a Int)

instance Collection MultiSet where
   singleton a = MS (M.singleton a 1)

instance Ord a => Monoid (MultiSet a) where
   mempty  = MS mempty
   mappend (MS m1) (MS m2) = MS (M.unionWith (+) m1 m2)

instance Ord a => Group (MultiSet a) where
   inverse (MS m) = MS (fmap negate m)

----------------------

newtype GroupSequence a = GS (Q.Seq (a, Bool))

instance Collection GroupSequence where
   singleton a = GS (Q.singleton (a, False))

instance Eq a => Monoid (GroupSequence a) where
   mempty = GS mempty
   mappend (GS xs) (GS ys) =
      case (Q.viewr xs, Q.viewl ys) of
         (as Q.:> (a, ai), (b, bi) Q.:< bs) | a == b && ai /= bi ->
            mappend (GS as) (GS bs)
         _ -> GS (xs <> ys)

instance Eq a => Group (GroupSequence a) where
   inverse (GS xs) = GS (fmap (second not) xs) -- actually: reverse order!!
-}
----------------------

instance CoMonoid [a] where
   isEmpty = null
   isAppend (x:xs@(_:_)) = Just ([x], xs)
   isAppend _            = Nothing

instance CoMonoid (S.Set a) where
   isEmpty = S.null
   isAppend s
      | S.size s > 1 = Just (first S.singleton (S.deleteFindMin s))
      | otherwise    = Nothing

{-
instance CoMonoid (Q.Seq a) where
   isEmpty = Q.null
   isAppend xs
      | n > 1     = Just (Q.splitAt (n `div` 2) xs)
      | otherwise = Nothing
    where
      n = Q.length xs
-}
instance CoMonoid a => CoMonoid (WithZero a) where
   isEmpty    = maybe False isEmpty . fromWithZero
   isAppend a = fromWithZero a >>= fmap (pure *** pure) . isAppend

instance CoMonoid a => CoMonoidZero (WithZero a) where
   isMonoidZero = isNothing . fromWithZero