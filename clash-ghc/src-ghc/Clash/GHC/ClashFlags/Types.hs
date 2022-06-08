module Clash.GHC.ClashFlags.Types
  ( ClashFlag(..)
  ) where

-- base
import Data.IORef (IORef, modifyIORef)

-- ghc
-- ghc
import GHC.Driver.CmdLine (EwM, Flag, liftEwM, OptKind (..), defFlag)

-- clash-lib
import Clash.Driver.Types (ClashOpts(..))

data ClashFlag = ClashFlag
  { cfFlags :: IORef ClashOpts -> [Flag IO]
  , cfRender :: ClashOpts -> [String]
  }

-------------------
-- flag builders --
-------------------

-- | Helper function....
validateAndSet ::
  IORef ClashOpts ->
  (a -> EwM IO (Maybe b)) ->
  (b -> ClashOpts -> ClashOpts) ->
  a ->
  EwM IO ()
validateAndSet ref validateFunc setFunc v0 = do
  v1 <- validateFunc v0
  case v1 of
    Nothing -> pure ()
    Just v2 -> liftEwM (modifyIORef ref (setFunc v2))

-- | Build NoArg flag....
noArg ::
  ClashFlag ->
  IORef ClashOpts ->
  (Bool -> ClashOpts -> ClashOpts) ->
  [Flag IO]
noArg proxy ref setFunc =
  [ defFlag ("fclash-"    <> flagName proxy) (NoArg (wrappedSetFunc True))
  , defFlag ("fclash-no-" <> flagName proxy) (NoArg (wrappedSetFunc False)) ]
 where
  wrappedSetFunc v = liftEwM (modifyIORef ref (setFunc v))

-- | Build IntSuffix / WordSuffix flag....
wordSuffix ::
  ClashFlag ->
  IORef ClashOpts ->
  -- | Parser / validator
  (Word -> EwM IO (Maybe b)) ->
  -- | Setter
  (b -> ClashOpts -> ClashOpts) ->
  [Flag IO]
wordSuffix proxy ref validateFunc setFunc =
  -- TODO: Newer versions of GHC support 'WordSuffix'. Use with CPP.
  -- TODO: Validate for older versions of GHC
  [ defFlag
      ("fclash-" <> flagName proxy)
      (IntSuffix (validateAndSet ref validateFunc setFunc . fromIntegral)) ]

-- | Build IntSuffix / WordSuffix flag....
wordSuffixId ::
  ClashFlag ->
  IORef ClashOpts ->
  -- | Setter
  (Word -> ClashOpts -> ClashOpts) ->
  [Flag IO]
wordSuffixId proxy ref = wordSuffix proxy ref (pure . Just)

-- | Build IntSuffix flag....
intSuffix ::
  ClashFlag ->
  IORef ClashOpts ->
  -- | Parser / validator
  (Int -> EwM IO (Maybe b)) ->
  -- | Setter
  (b -> ClashOpts -> ClashOpts) ->
  [Flag IO]
intSuffix proxy ref validateFunc setFunc =
  [ defFlag
      ("fclash-" <> flagName proxy)
      (IntSuffix (validateAndSet ref validateFunc setFunc)) ]

-- | Build IntSuffix flag....
intSuffixId ::
  ClashFlag ->
  IORef ClashOpts ->
  -- | Setter
  (Int -> ClashOpts -> ClashOpts) ->
  [Flag IO]
intSuffixId proxy ref = intSuffix proxy ref (pure . Just)

-- | Build StrSuffix flag....
strSuffix ::
  ClashFlag ->
  IORef ClashOpts ->
  -- | Parser / validator
  (String -> EwM IO (Maybe b)) ->
  -- | Setter
  (b -> ClashOpts -> ClashOpts) ->
  [Flag IO]
strSuffix proxy ref validateFunc setFunc =
  [ defFlag
      ("fclash-" <> flagName proxy)
      (SepArg (validateAndSet ref validateFunc setFunc)) ]

-- | Build IntSuffix flag....
strSuffixId ::
  ClashFlag ->
  IORef ClashOpts ->
  -- | Setter
  (String -> ClashOpts -> ClashOpts) ->
  [Flag IO]
strSuffixId proxy ref = strSuffix proxy ref (pure . Just)



-------------------
-- flag renderers --
-------------------

-- | Render a bool flag with given name and value unconditionally
renderNoArg :: ClashFlag -> Bool -> [String]
renderNoArg proxy value
  | value = ["-fclash-" <> flagName proxy]
  | otherwise = ["-fclash-no-" <> flagName proxy]

renderSuffix :: ClashFlag -> String -> [String]
renderSuffix proxy value = ["-fclash-" <> flagName proxy <> "=" <> value]


----------------------
-- flag definitions --
----------------------
