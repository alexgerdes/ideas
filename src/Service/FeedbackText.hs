-----------------------------------------------------------------------------
-- Copyright 2009, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Service.FeedbackText 
   ( feedbackLogic
   , onefirsttext, submittext, derivationtext
   ) where

import Control.Arrow
import Control.Monad
import Common.Exercise
import Common.Utils (safeHead, fst3, commaList)
import Data.Maybe
import Domain.Logic.Formula (SLogic)
import Domain.Logic.FeedbackText
import Domain.Logic.Exercises (dnfExercise)
import Domain.Logic.Difference (difference)
import Service.TypedAbstractService
import Common.Context
import Common.Exercise
import Common.Transformation (name, Rule)
import Text.Parsing (errorToPositions)

-- Quick hack for determining subterms
coerceLogic :: Exercise a -> a -> Maybe SLogic
coerceLogic ex a =
   case parser dnfExercise (prettyPrinter ex a) of
      Right p | exerciseCode ex == exerciseCode dnfExercise
        -> Just p
      _ -> Nothing

youRewroteInto :: State a -> a -> Maybe String
youRewroteInto = rewriteIntoText "You rewrote "

useToRewrite :: Rule (Context a) -> State a -> a -> Maybe String
useToRewrite rule old = rewriteIntoText txt old
 where
   txt = "Use " ++ showRule (exerciseCode $ exercise old) rule
         ++ " to rewrite "

-- disabled for now
rewriteIntoText :: String -> State a -> a -> Maybe String
rewriteIntoText txt old a = Nothing {- do 
   p <- coerceLogic (exercise old) (fromContext $ context old)
   q <- coerceLogic (exercise old) a
   (p1, q1) <- difference p q
   return $ txt ++ prettyPrinter dnfExercise p1 
         ++ " into " ++ prettyPrinter dnfExercise q1 ++ ". " -}

-- Feedback messages for submit service (free student input). The boolean
-- indicates whether the student is allowed to continue (True), or forced 
-- to go back to the previous state (False)
feedbackLogic :: State a -> a -> Result a -> (String, Bool)
feedbackLogic old a result =
   case result of
      Buggy rs        -> ( fromMaybe ""  (youRewroteInto old a) ++ 
                           feedbackBuggy (ready old) rs
                         , False)
      NotEquivalent   -> ( fromMaybe ""  (youRewroteInto old a) ++
                           feedbackNotEquivalent (ready old)
                         , False)
      Ok rs _
         | null rs    -> (feedbackSame, False)
         | otherwise  -> feedbackOk rs
      Detour rs _     -> feedbackDetour (ready old) (expected old) rs
      Unknown _       -> ( fromMaybe ""  (youRewroteInto old a) ++ 
                           feedbackUnknown (ready old)
                         , False)
 where
   expected = fmap fst3 . safeHead . allfirsts

showRule :: ExerciseCode -> Rule a -> String
showRule code r 
   | code == exerciseCode dnfExercise =
        fromMaybe txt (ruleText r)
   | otherwise = txt
 where
   txt = "rule " ++ name r

getCode :: State a -> ExerciseCode
getCode = exerciseCode . exercise

derivationtext :: State a -> [(String, Context a)]
derivationtext st = map (first (showRule (getCode st))) (derivation st)
   
onefirsttext :: State a -> (Bool, String, State a)
onefirsttext state =
   case allfirsts state of
      (r, _, s):_ -> 
         case useToRewrite r state (fromContext $ context s) of
            Just txt -> (True, txt, s)
            Nothing  -> (True, "Use " ++ showRule (getCode state) r, s)
      _ -> (False, "Sorry, no hint available", state)

submittext :: State a -> String -> (Bool, String, State a)
submittext state txt = 
   case parser (exercise state) txt of
      Left err -> 
         let msg = "Syntax error" ++ pos ++ ": " ++ show err
             pos = case map show (errorToPositions err) of
                      [] -> ""
                      xs -> " at " ++ commaList xs
         in (False, msg, state)
      Right a  -> 
         let result = submit state a
             (txt, b) = feedbackLogic state a result
         in case getResultState result of
               Just new | b -> (True, txt, resetStateIfNeeded new)
               _ -> (False, txt, state)