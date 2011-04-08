-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- Simple parser for feedback scripts
--
-----------------------------------------------------------------------------
module Service.FeedbackScript.Parser (parseScript, Script) where

import Common.Id
import Control.Monad.Error
import Data.Char
import Data.Monoid
import Service.FeedbackScript.Syntax
import Text.ParserCombinators.Parsec.Char
import Text.ParserCombinators.Parsec.Prim
import Text.ParserCombinators.Parsec

parseScript :: FilePath -> IO Script
parseScript file = do
   result <- parseFromFile script file
   case result of
      Left e   -> print e >> return mempty
      Right xs -> return xs

script :: CharParser st Script
script = do
   lexeme (return ())
   xs <- decls
   eof
   return (makeScript xs)

decls :: CharParser st [Decl]
decls = many $ do 
   pos <- getPosition
   guard (sourceColumn pos == 1)
   decl

decl :: CharParser st Decl
decl = do
   dt <- declType
   a  <- identifiers
   f  <- (simpleDecl <|> guardedDecl)
   return (f dt a)
 <|> do
   lexString "namespace"
   liftM NameSpace identifiers
 <|> do
   lexString "supports"
   liftM Supports identifiers
 <?> "declaration"

simpleDecl, guardedDecl :: CharParser st (DeclType -> [Id] -> Decl)
simpleDecl  = liftM (\t dt a -> Simple dt a t) text
guardedDecl = do
   xs <- many1 $ do
            c <- lexChar '|' >> condition
            t <- text
            return (c, t)
   return (\dt a -> Guarded dt a xs)

declType :: CharParser st DeclType
declType =  (lexString "text"     >> return TextForId)
        <|> (lexString "string"   >> return StringDecl)
        <|> (lexString "feedback" >> return Feedback)

condition :: CharParser st Condition
condition = choice
   [ lexeme (liftM CondRef attribute)
   , lexString "recognize" >> lexeme (liftM RecognizedIs identifier)
   , lexString "true"  >> return (CondConst True)
   , lexString "false" >> return (CondConst False)
   , lexString "not" >> liftM CondNot condition
   ]

text :: CharParser st Text
text = do 
   skip (lexChar '=')
   (singleLineText <|> multiLineText)

singleLineText :: CharParser st Text
singleLineText = do 
   xs <- manyTill textItem (lexeme (skip newline <|> comment))
   return (mconcat xs)

multiLineText :: CharParser st Text
multiLineText = do 
   skip (char '{')
   xs <- manyTill (textItem <|> (newline >> return mempty)) (lexChar '}')
   return (mconcat xs)

textItem :: CharParser st Text
textItem = liftM makeText (many1 (noneOf "@#{}\n" <|> try escaped))
       <|> liftM TextRef attribute
 where
   escaped = skip (char '@') >> satisfy (not . isAlphaNum)

identifiers :: CharParser st [Id]
identifiers = sepBy1 identifier (lexChar ',')

-- Lexical units
identifier :: CharParser st Id
identifier = lexeme (do
   xs <- idPart `sepBy1` char '.'
   return (mconcat (map newId xs))) 
 <?> "identifier"
 where
   idPart   = many1 idLetter
   idLetter = alphaNum <|> oneOf "-_"

attribute :: CharParser st Id
attribute = do
   skip (char '@')
   s <- many1 (alphaNum <|> oneOf "-_") -- identifier?
   return (newId s)
 <?> "attribute"
 
lexChar :: Char -> CharParser s ()
lexChar = skip . lexeme . char

lexString :: String -> CharParser s ()
lexString s = skip (lexeme (try (string s))) <?> "string " ++ show s

comment :: CharParser st ()
comment = skip (char '#' >> manyTill (noneOf "\n") (skip newline <|> eof))

skip :: CharParser st a -> CharParser st ()
skip p = p >> return ()

-- parse white space and comments afterwards   
lexeme :: CharParser s a -> CharParser s a
lexeme p = do 
   a <- p
   skipMany (skip space <|> comment)
   return a