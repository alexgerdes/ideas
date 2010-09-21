-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  alex.gerdes@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.Power.Rules 
  ( -- * Power rules
    calcPower, calcPowerPlus, calcPowerMinus, addExponents, mulExponents
  , subExponents, distributePower, distributePowerDiv, zeroPower, reciprocal
  , reciprocalInv, reciprocalFrac, greatestPower, commonPower, nthRoot
  , approxPower
    -- * Root rules
  , power2root, root2power, distributeRoot, mulRoot, mulRootCom, divRoot
  , simplifyRoot
    -- * Common rules
  , myFractionTimes, simplifyFraction, pushNegOut
    -- * Help functions
  , smartRule, powerRuleOrder, hasNegExp
  ) where

import Prelude hiding ( (^) )
import qualified Prelude
import Common.Classes
import Common.Context
import Control.Arrow ( (>>^) )
import Common.Id
import Common.Transformation
import Common.View
import Control.Monad
import Data.List
import Data.Maybe
import Domain.Math.Approximation (precision)
import qualified Domain.Math.Data.PrimeFactors as PF
import Domain.Math.Data.OrList
import Domain.Math.Data.Relation
import Domain.Math.Expr
import Domain.Math.Numeric.Views
import Domain.Math.Power.Views
import Domain.Math.Polynomial.CleanUp

-- | Rule ordering ------------------------------------------------------------
powerRuleOrder = map getId
  [ addExponents
  , mulExponents
  , subExponents
  , distributePower
  , reciprocal
  ]  

power = "algebra.manipulation.exponents"


-- | Power relation rules -----------------------------------------------------

-- x = n  =>  x = a^e  (with e /= 1)
greatestPower :: Rule Expr
greatestPower = makeSimpleRule (power, "greatest-power") $ \ expr -> do
    n      <- match natView expr
    (a, x) <- PF.greatestPower $ toInteger n
    return $ fromInteger a .^. fromInteger x

-- a^x = b^y  =>  a^(x/c) = b^(y/c)  where c = gcd x y
commonPower :: Rule (Equation Expr)
commonPower = makeSimpleRule (power, "common-power") $ \(lhs :==: rhs) -> do
    (a, x) <- match simplePowerView lhs
    x'     <- match integerView x
    (b, y) <- match simplePowerView rhs
    y'     <- match integerView y
    let c = gcd x' y'
    guard (c > 1)
    return $ a .^. build integerView (x' `div` c) :==: 
             b .^. build integerView (y' `div` c)

-- a^x = b^y  =>  a = b^(y/x) = root x (b^y)  (y may be 1)
nthRoot :: Rule (Equation Expr)
nthRoot = makeSimpleRule (power, "nth-root") $ \(lhs :==: rhs) -> do
    (a, x) <- match simplePowerView lhs
    (b, y) <- match (simplePowerView <&> (identity >>^ (\x->(x,1)))) rhs
    return $ a :==: b .^. (y ./. x)

approxPower :: Rule (Relation Expr)
approxPower = makeSimpleRule (power, "approx-power") $ \ expr ->
  match equationView expr >>= f
  where
    f (Var x :==: d) = match doubleView d >>= Just . (Var x .~=.) . Number . precision 3 
    f (d :==: Var x) = match doubleView d >>= Just . (.~=. Var x) . Number . precision 3
    f _              = Nothing


-- | Power rules --------------------------------------------------------------

calcPower :: Rule Expr 
calcPower = makeSimpleRule "arithmetic.operation.rational.power" $ \ expr -> do 
  (e1, e2) <- match simplePowerView expr
  a        <- match rationalView e1
  x        <- match integralView e2
  if x > 0 
    then return $ fromRational $ a Prelude.^ x
    else return $ 1 ./. (e1 .^. neg e2)

calcPowerPlus :: Rule Expr 
calcPowerPlus = 
  makeCommutative sumView (.+.) $ calcBinPowerRule "plus" (.+.) isPlus 

calcPowerMinus :: Rule Expr 
calcPowerMinus = 
   makeCommutative sumView (.+.) $ calcBinPowerRule "minus" (.-.) isMinus

-- | a*x^y * b*x^q = a*b * x^(y+q)
addExponents :: Rule Expr 
addExponents = makeSimpleRuleList (power, "add-exponents") $ \ expr -> do
  case match (powerFactorisationView unitPowerView) expr of
    Just (s, fs) -> do 
      (e, es) <- split (*) fs
      case apply addExponentsT e of
        Just e' -> return $ build productView (s, e' : es)
        Nothing -> fail ""  
    Nothing -> fail ""

-- | a*x^y * b*x^q = a*b * x^(y+q)
addExponentsT :: Transformation Expr 
addExponentsT = makeTrans $ \ expr -> do
  x        <- selectVar expr
  (e1, e2) <- match timesView expr
  (a, y)   <- match (unitPowerForView x) e1
  (b, q)   <- match (unitPowerForView x) e2
  return $ build (unitPowerForView x) (a .*. b, y + q)
  
-- | a*x^y / b*x^q = a/b * x^(y-q)
subExponents :: Rule Expr
subExponents = forallVars rule
  where
    rule x = makeSimpleRule (power, "sub-exponents") $ \ expr -> do
      (e1, e2) <- match divView expr
      (a, y)   <- match (unitPowerForView x) e1
      (b, q)   <- match (unitPowerForView x) e2
      return $ build (unitPowerForView x) (a ./. b, y - q)

-- | (c*a^x)^y = c*a^(x*y)
mulExponents :: Rule Expr 
mulExponents = makeSimpleRule (power, "mul-exponents") $ \ expr -> do
  (cax, y)    <- match simplePowerView expr
  (c, (a, x)) <- match strictPowerView cax
  guard (c == 1 || c == -1)
  selectVar a
  return $ build strictPowerView (c, (a, x .*. y))

-- | c*(a0..an)^y = c * a0^y * a1^y .. * an^y
distributePower :: Rule Expr
distributePower = makeSimpleRule (power, "distr-power") $ \ expr -> do
  (c, (as', y)) <- match strictPowerView expr
  y'            <- match integerView y
  (sign, as)    <- match productView as'
  guard (length as > 1)
  return $ build productView 
   (if sign then odd y' else False, c : map (\a -> a .^. y) as)

-- | c * (a/b)^y = c * (a^y / b^y)
distributePowerDiv :: Rule Expr
distributePowerDiv = makeSimpleRule (power, "distr-power-div") $ \ expr -> do
  (c, (ab, y)) <- match strictPowerView expr
  match integerView y
  (a, b)       <- match divView ab
  return $ c .*. build divView (a .^. y, b .^. y)

-- | c*a^0 = c
zeroPower :: Rule Expr
zeroPower = makeSimpleRule (power, "zero-power") $ \ expr -> do
  (_, (c, y)) <- match strictPowerView expr
  y' <- match integerView y
  guard (y'==0)
  return c

-- | d/c*a^x = d*a^(-x)/c
reciprocal :: Rule Expr
reciprocal = makeSimpleRule (power, "reciprocal") $ \ expr -> do
  a        <- selectVar expr
  (d, cax) <- match divView expr
  (c, x)   <- match (unitPowerForView a) cax
  return $ build (unitPowerForView a) (d ./. c, negate x)

-- | c*a^x = c/a^(-x)
reciprocalInv ::  Rule Expr
reciprocalInv = makeSimpleRule (power, "reciprocal-inverse") $ \ expr -> do
  guard (hasNegExp expr)
--  a        <- selectVar expr
  (c, (a, x)) <- match strictPowerView expr
  return $ c ./. build strictPowerView (1, (a, neg x))

-- | c / d*a^(-x)*b^(-y)...p^r... = c*a^x*b^y.../d*p^r...
reciprocalFrac :: Rule Expr
reciprocalFrac = makeSimpleRule (power, "reciprocal-frac") $ \ expr -> do
  (e1, e2) <- match divView expr
  (s, xs)  <- match productView e2
  let (ys, zs) = partition hasNegExp xs
  guard (not $ null ys)
  return $ e1 .*. build productView (s, map f ys) ./. build productView (False, zs)
    where
      f e = case match strictPowerView e of
              Just (c, (a, x)) -> build strictPowerView (c, (a, neg x))
              Nothing          -> e
  

-- | Root rules ----------------------------------------------------------------

-- | a^(p/q) = root (a^p) q
power2root :: Rule Expr 
power2root = makeSimpleRule (power, "write-as-root") $ \ expr -> do
  (a, pq) <- match simplePowerView expr
  (p, q)  <- match (rationalView >>> ratioView) pq  
  guard (q /= 1)  
  return $ let n =  fromInteger . fromIntegral in root (a .^. n p) $ n q
  
-- | root (a^p) q = a^(p/q)
root2power :: Rule Expr 
root2power = makeSimpleRule (power, "write-as-power") $ \ expr -> do
  (ap, q) <- match rootView expr
  a       <- selectVar ap
  p       <- match (powerViewFor' a) ap
  return $ build (powerViewFor' a) (fromRational (p /  q))

-- | root (a/b) x = root a x / root b x
distributeRoot :: Rule Expr
distributeRoot = makeSimpleRule (power, "distr-root") $ \ expr -> do
  (ab, x) <- match rootView expr
  (a, b)  <- match divView ab
  return $ build divView (build rootView (a, x), build rootView (b, x))  

-- | c1 root a x * c2 root b x = c1*c2 * root (a*b) x
mulRoot :: Rule Expr
mulRoot = describe "Multiply base of root" $ 
   makeSimpleRule (power, "multipy-base") $ \ expr -> do
  (r1, r2)      <- match timesView expr
  (c1, (a, x))  <- match rootConsView r1
  (c2, (b, x')) <- match rootConsView r2
  guard (x == x')
  return $ build rootConsView (c1 .*. c2, (a .*. b, x))

-- | commutative version of the mulRoot rule
mulRootCom :: Rule Expr
mulRootCom = makeCommutative (myProductView (powerFactorisationView rootView)) (.*.) mulRoot
 where
   myProductView :: View Expr (Bool, [Expr]) -> View Expr [Expr]
   myProductView v = v >>> makeView f g
     where
       f (s, (x:xs)) = return $ if s then neg x : xs else x:xs
       f _           = fail ""
       g = (,) False 

-- | c1 * root a x / c2 * root b x = c1*c2 * root (a/b) x
divRoot :: Rule Expr
divRoot = describe "divide base of root" $
   makeSimpleRule (power, "divide-base") $ \ expr -> do
  (r1, r2) <- match divView expr
  (c1, (a, x))  <- match rootConsView r1
  (c2, (b, x')) <- match rootConsView r2
  guard (x == x' && b /= 0)
  return $ build rootConsView (c1 .*. c2, (a ./. b, x))

-- | root 0 x = 0  ;  root 1 x = 1  ;  root a 1 = a
simplifyRoot :: Rule Expr
simplifyRoot = makeSimpleRule (power, "simplify-root") $ \e -> f e `mplus` g e
 where
  f expr = do
    (e1, _) <- match rootView expr
    x       <- match integerView e1
    case x of
      0 -> Just 0
      1 -> Just 1
      _ -> Nothing
  g expr = do
    (e1, e2) <- match rootView expr
    if e2 == 1 then Just e1 else Nothing


-- | Common rules --------------------------------------------------------------

-- | a/b * c/d = a*c / b*d  (b or else d may be one)  
myFractionTimes :: Rule Expr
myFractionTimes = smartRule $ makeSimpleRule (power, "fraction-times") $ \ expr -> do
  (e1, e2) <- match timesView expr
  guard $ isJust $ match divView e1 `mplus` match divView e2
--  guard $ not $ isJust $ match rationalView e1 `mplus` match rationalView e2
  (a, b)   <- match (divView <&> (identity >>^ \e -> (e,1))) e1
  (c, d)   <- match (divView <&> (identity >>^ \e -> (e,1))) e2
  return $ build divView (a .*. c, b .*. d)

-- | simplify expression
simplifyFraction :: Rule Expr
simplifyFraction = makeSimpleRule (power, "simplify-fraction") $ \ expr -> do
  let expr' = simplifyWith (second normalizeProduct) productView $ expr
  guard (expr /= expr')
  guard $ not $ applicable myFractionTimes expr'
  return expr'

-- | (-a)^x = (-)a^x
pushNegOut :: Rule Expr
pushNegOut = makeSimpleRule (power, "push-negation-out") $ \ expr -> do
  (a, x) <- match simplePowerView expr
  a'     <- isNegate a
  x'     <- match integerView x
  return $ (if odd x' then neg else id) $ build simplePowerView (a', x)


-- | Help functions -----------------------------------------------------------

smartRule :: Rule Expr -> Rule Expr
smartRule = doAfter f
  where
    f (a :*: b) = a .*. b
    f (a :/: b) = a ./. b
    f (Negate a) = neg a
    f (a :+: b) = a .+. b
    f (a :-: b) = a .-. b
    f e = e
   
calcBinPowerRule :: String -> (Expr -> Expr -> Expr) -> (Expr -> Maybe (Expr, Expr)) -> Rule Expr   
calcBinPowerRule opName op m = 
   makeSimpleRule (power, "calc-power", opName) $ \e -> do
     (e1, e2)     <- m e
     (a, (c1, x)) <- match unitPowerView e1
     (b, (c2, y)) <- match unitPowerView e2
     guard (a == b && x == y)
     return (build unitPowerView (a, ((op c1 c2), x)))

makeCommutative :: View Expr [Expr] -> (Expr -> Expr -> Expr) -> Rule Expr -> Rule Expr
makeCommutative view op rule = 
  makeSimpleRuleList (getId rule) $ \ expr -> do
    case match view expr of
      Just factors -> do
        (e, es) <- split op factors
        case apply rule e of
          Just e' -> return $ build view (e' : es)
          Nothing -> fail ""
      Nothing -> fail ""

split :: (Eq a) => (a -> a -> t) -> [a] -> [(t, [a])]    
split op xs = f xs
      where
        f (y:ys) | not (null ys) = [(y `op` z, xs \\ [y, z]) | z <- ys] ++ f ys 
                 | otherwise     = []
        f [] = []

forallVars :: (String -> Rule Expr) -> Rule Expr
forallVars ruleFor = makeSimpleRuleList (getId (ruleFor "")) $ \ expr -> 
  mapMaybe (\v -> apply (ruleFor v) expr) $ collectVars expr

hasNegExp expr = 
  case match strictPowerView expr of
    Just (_, (_, x)) -> case match rationalView x of
      Just x' -> x' < 0
      _       -> False
    _ -> False
