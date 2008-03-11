module OpenMath.LAServer (respond, laServerFor, versionNr) where

import Domain.LinearAlgebra
import OpenMath.StrategyTable
import OpenMath.Request
import OpenMath.Reply
import OpenMath.ObjectParser
import Common.Apply
import Common.Context
import Common.Transformation
import Common.Strategy hiding (not)
import Common.Exercise hiding (Incorrect)
import Common.Utils
import Data.Maybe
import Data.Char
import Data.List

respond :: Maybe String -> String
respond = replyInXML . maybe requestError (either parseError laServer . pRequest)

replyError :: String -> String -> Reply
replyError kind = Error . ReplyError kind

parseError :: String -> Reply
parseError   = replyError "parse error"

requestError :: Reply
requestError = replyError "request error" "no request found in \"input\""

(~=) :: String -> String -> Bool
xs ~= ys = let f = map toLower . filter isAlphaNum
           in f xs == f ys 

laServer :: Request -> Reply
laServer req = 
   case [ ea | Entry _ ea@(Some (ExprExercise a)) _ _ <- strategyTable, req_Strategy req ~= shortTitle a ] of
      [Some (ExprExercise a)] -> laServerFor a req
      _ -> replyError "request error" "unknown strategy"
   
laServerFor :: IsExpr a => Exercise (Context a) -> Request -> Reply
laServerFor a req = 
   case getContextTerm req of
   
      _ | isJust $ subStrategy (req_Location req) (strategy a) ->
             replyError "request error" "invalid location for strategy"
         
      Nothing ->
         replyError "request error" ("invalid term for " ++ show (req_Strategy req))
         
      Just requestedTerm ->          
         case (runPrefixLocation (req_Location req) (getPrefix req (strategy a)) requestedTerm, maybe Nothing (fmap inContext . fromExpr) $ req_Answer req) of
            ([], _) -> replyError "strategy error" "not able to compute an expected answer"
            
            (answers, Just answeredTerm)
               | not (null witnesses) ->
                    Ok $ ReplyOk
                       { repOk_Strategy = req_Strategy req
                       , repOk_Location = nextTask (req_Location req) $ nextMajorForPrefix newPrefix (fst $ head witnesses)
                       , repOk_Context  = show newPrefix ++ ";" ++ 
                                          showContext (fst $ head witnesses)
                       , repOk_Steps    = stepsRemaining newPrefix (fst $ head witnesses)
                       }
                  where
                    witnesses   = filter (equality a answeredTerm . fst) answers
                    newPrefix   = snd (head witnesses)
                       
            ((expected, prefix):_, maybeAnswer) ->
                    Incorrect $ ReplyIncorrect
                       { repInc_Strategy   = req_Strategy req
                       , repInc_Location   = subTask (req_Location req) loc
                       , repInc_Expected   = toExpr (fromContext expected)
                                             -- only return arguments if we are at a rule
                       , repInc_Arguments  = if loc==req_Location req then args else Nothing
                       , repInc_Steps      = stepsRemaining (getPrefix req (strategy a)) requestedTerm
                       , repInc_Equivalent = maybe False (equivalence a expected) maybeAnswer
                       }
             where
               (loc, args) = firstMajorInPrefix (getPrefix req (strategy a)) prefix requestedTerm

-- old (current) and actual (next major rule) location
subTask :: [Int] -> [Int] -> [Int]
subTask (i:is) (j:js)
   | i == j    = i : subTask is js
   | otherwise = []
subTask _ js   = take 1 js

-- old (current) and actual (next major rule) location
nextTask :: [Int] -> [Int] -> [Int]
nextTask (i:is) (j:js)
   | i == j    = i : nextTask is js
   | otherwise = [j] 
nextTask _ _   = [] 

firstMajorInPrefix :: Prefix a -> Prefix a -> a -> ([Int], Maybe String)
firstMajorInPrefix p0 prefix a = fromMaybe ([], Nothing) $ do
   let steps = prefixToSteps prefix
       newSteps = drop (length $ prefixToSteps p0) steps
   is    <- safeHead [ is | Step is r <- newSteps, not (isMinorRule r) ]
   return (is, argumentsForSteps a newSteps)
 
argumentsForSteps :: a -> [Step a] -> Maybe String
argumentsForSteps a = safeHead . flip rec a . stepsToRules
 where
   showList xs = "(" ++ concat (intersperse "," xs) ++ ")"
   rec [] _ = []
   rec (r:rs) a
      | isMinorRule r  = concatMap (rec rs) (applyAll r a)
      | applicable r a = maybe [] (return . showList) (expectedArguments r a)
      | otherwise      = []
 
nextMajorForPrefix :: Prefix a -> a -> [Int]
nextMajorForPrefix p0 a = fromMaybe [] $ do
   (_, p1)  <- safeHead $ runPrefixMajor p0 a
   let steps = prefixToSteps p1
   lastStep <- safeHead (reverse steps)
   case lastStep of
      Step is r | not (isMinorRule r) -> return is
      _ -> Nothing