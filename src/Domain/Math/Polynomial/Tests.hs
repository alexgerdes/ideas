module Domain.Math.Polynomial.Tests where

import Control.Monad
import Common.Apply
import Common.Exercise
import Common.Context
import Common.Strategy
import Domain.Math.Data.Equation
import Domain.Math.Data.OrList
import Domain.Math.ExercisesDWO
import Domain.Math.Polynomial.Exercises
import Domain.Math.Polynomial.Generators
import Test.QuickCheck

import Common.View
import Domain.Math.Expr
import Prelude hiding ((^))
import Domain.Math.Polynomial.Views
import Domain.Math.Polynomial.CleanUp

q = raar

-- see the derivations for the DWO exercise set
seeLE  n = printDerivation linearExercise $ concat linearEquations !! n
seeQE  n = printDerivation quadraticExercise $ OrList $ return $ concat quadraticEquations !! n
seeHDE n = printDerivation higherDegreeExercise $ OrList $ return $ higherDegreeEquations !! n

-- test strategies with DWO exercise set
testLE  = concat $ zipWith (f linearExercise)       [0..] $ concat linearEquations
testQE  = concat $ zipWith (f quadraticExercise)    [0..] $ map (OrList . return) $ concat quadraticEquations
testHDE = concat $ zipWith (f higherDegreeExercise) [0..] $ map (OrList . return) $ higherDegreeEquations

f s n e = map p (g (applyAll (strategy s) (inContext e))) where
  g xs | null xs   = error $ show n ++ ": " ++ show e
       | otherwise = xs
  p a  | finalProperty s (fromContext a) = n
       | otherwise = error $ show n ++ ": " ++ show e ++ "  =>  " ++ show (fromContext a)
       
randomLE = quickCheck $ forAll (liftM2 (:==:) (sized linearGen) (sized linearGen)) $ \eq -> 
   (>0) (sum (take 10 $ f linearExercise 1 (eq)))
randomQE = quickCheck $ forAll (liftM2 (:==:) (sized quadraticGen) (sized quadraticGen)) $ \eq -> 
   (>0) (sum (take 10 $ f quadraticExercise 1 (OrList [eq])))
   
eqQE = concat $ zipWith (g quadraticExercise) [0..] $ map (OrList . return) $ concat quadraticEquations

g s n e = map p (h (derivations (unlabel $ strategy s) (inContext e))) where
  h xs | null xs   = error $ show n ++ ": " ++ show e
       | otherwise = xs
  p (a, xs) = case [ (x, y) | x <- ys, y <- ys, Prelude.not (equivalence s x y) ] of
                 [] -> let l = length xs in l*l
                 (x, y):_ -> error $ show n ++ ": " ++ show x ++ "   is not   " ++ show y
   where ys = map fromContext (a : map snd xs)
   
   
e1 = match higherDegreeEquationsView $ OrList [(x :==: 2)] where x = Var "x"
-- e2 = simplify rationalView (Sqrt ())