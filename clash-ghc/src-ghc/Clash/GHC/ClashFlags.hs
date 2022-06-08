{-|
  Copyright   :  (C) 2015-2016, University of Twente,
                     2016-2017, Myrtle Software Ltd,
                     2021,      QBayLogic B.V.
  License     :  BSD2 (see the file LICENSE)
  Maintainer  :  QBayLogic B.V. <devops@qbaylogic.com>
-}

{-# LANGUAGE CPP #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

{-# OPTIONS_GHC -Wno-unrecognised-pragmas #-}

{-# HLINT ignore "Use ++" #-}

module Clash.GHC.ClashFlags
  ( parseClashFlags
  , flagsClash
  )
where

#define WORD_SIZE_IN_BITS 64

#if MIN_VERSION_ghc(9,0,0)
import           GHC.Driver.CmdLine
  (Warn, Flag, EwM, processArgs, errorsToGhcException, errMsg, addErr, defFlag, OptKind (..), liftEwM)
import           GHC.Utils.Panic
import           GHC.Types.SrcLoc
import           GHC.TypeLits (KnownSymbol)
#else
import           CmdLineParser
import           Panic
import           SrcLoc
#endif

import           Control.Monad
import           Data.Char                      (isSpace)
import           Data.IORef
import           Data.List                      (dropWhileEnd, intercalate)
import           Data.List.Split                (splitOn)
import           Data.Proxy
import qualified Data.Set                       as Set
import           Data.Set                       (Set)
import qualified Data.Text                      as Text
import           Data.Text                      (Text)
import           Text.Read                      (readMaybe)

import           Clash.Driver.Types
import           Clash.Netlist.BlackBox.Types   (HdlSyn (..))
import           Clash.Netlist.Types            (PreserveCase (ToLower, PreserveCase))
import           Clash.Promoted.Symbol          (ssymbolProxy, ssymbolToString)

parseClashFlags ::
  IORef ClashOpts ->
  [Located String] ->
  IO ([Located String], [Warn])
parseClashFlags r = parseClashFlagsOrErr (flagsClash r)

parseClashFlagsOrErr ::
  [Flag IO] ->
  [Located String] ->
  IO ([Located String], [Warn])
parseClashFlagsOrErr flagsAvialable args = do
  (leftovers, errs, warns) <- processArgs flagsAvialable args

  unless (null errs) $ throwGhcExceptionIO $
    errorsToGhcException . map (("on the commandline", ) .  unLoc . errMsg)
                         $ errs

  return (leftovers, warns)

flagsClash :: IORef ClashOpts -> [Flag IO]
flagsClash ref = concat
  [ getFlags @"render-enums" Proxy ref
  , getFlags @"edalize" Proxy ref
  ]

<<<<<<< HEAD
-- | Print deprecated flag warning
deprecated
  :: String
  -- ^ Deprecated flag
  -> String
  -- ^ Use X instead
  -> (a -> IO ())
  -> a
  -> EwM IO ()
deprecated wrong right f a = do
  addWarn ("Using '-fclash-" ++ wrong
                             ++ "' is deprecated. Use '-fclash-"
                             ++ right
                             ++ "' instead.")
  liftEwM (f a)

setInlineLimit :: IORef ClashOpts
               -> Int
               -> IO ()
setInlineLimit r n = modifyIORef r (\c -> c {_opt_inlineLimit = n})

setInlineFunctionLimit
  :: IORef ClashOpts
  -> Int
  -> IO ()
setInlineFunctionLimit r n = modifyIORef r (\c -> c {_opt_inlineFunctionLimit = toEnum n})

setInlineConstantLimit
  :: IORef ClashOpts
  -> Int
  -> IO ()
setInlineConstantLimit r n = modifyIORef r (\c -> c {_opt_inlineConstantLimit = toEnum n})

setEvaluatorFuelLimit
  :: IORef ClashOpts
  -> Int
  -> IO ()
setEvaluatorFuelLimit r n = modifyIORef r (\c -> c {_opt_evaluatorFuelLimit = toEnum n})

setInlineWFLimit
  :: IORef ClashOpts
  -> Int
  -> IO ()
setInlineWFLimit r n = modifyIORef r (\c -> c {_opt_inlineWFCacheLimit = toEnum n})

setSpecLimit :: IORef ClashOpts
             -> Int
             -> IO ()
setSpecLimit r n = modifyIORef r (\c -> c {_opt_specLimit = n})

setDebugInvariants :: IORef ClashOpts -> IO ()
setDebugInvariants r =
  modifyIORef r $ \c ->
    c { _opt_debug = (_opt_debug c) { _dbg_invariants = True } }

setDebugCountTransformations :: IORef ClashOpts -> IO ()
setDebugCountTransformations r =
  modifyIORef r $ \c ->
    c { _opt_debug = (_opt_debug c) { _dbg_countTransformations = True } }

setDebugTransformations :: IORef ClashOpts -> String -> EwM IO ()
setDebugTransformations r s =
  liftEwM (modifyIORef r (setTransformations transformations))
=======
noArg ::
  ClashFlag a =>
  Proxy a ->
  IORef ClashOpts ->
  (Bool -> ClashOpts -> ClashOpts) ->
  [Flag IO]
noArg proxy ref setFunc =
  [ defFlag ("fclash-"    <> flagName proxy) (NoArg (wrappedSetFunc True))
  , defFlag ("fclash-no-" <> flagName proxy) (NoArg (wrappedSetFunc False)) ]
>>>>>>> 24fdf1ba (f)
 where
  wrappedSetFunc v = liftEwM (modifyIORef ref (setFunc v))

<<<<<<< HEAD
  setTransformations xs opts =
    opts { _opt_debug = (_opt_debug opts) { _dbg_transformations = xs } }

setDebugTransformationsFrom :: IORef ClashOpts -> Int -> EwM IO ()
setDebugTransformationsFrom r n =
  liftEwM (modifyIORef r (setFrom (fromIntegral n)))
 where
  setFrom from opts =
    opts { _opt_debug = (_opt_debug opts) { _dbg_transformationsFrom = Just from } }

setDebugTransformationsLimit :: IORef ClashOpts -> Int -> EwM IO ()
setDebugTransformationsLimit r n =
  liftEwM (modifyIORef r (setLimit (fromIntegral n)))
 where
  setLimit limit opts =
    opts { _opt_debug = (_opt_debug opts) { _dbg_transformationsLimit = Just limit } }

setDebugLevel :: IORef ClashOpts -> String -> EwM IO ()
setDebugLevel r s =
  case s of
    "DebugNone" ->
      liftEwM $ modifyIORef r (setLevel debugNone)
    "DebugSilent" ->
      liftEwM $ do
        modifyIORef r (setLevel debugSilent)
        setNoCache r
    "DebugFinal" ->
      liftEwM $ do
        modifyIORef r (setLevel debugFinal)
        setNoCache r
    "DebugCount" ->
      liftEwM $ do
        modifyIORef r (setLevel debugCount)
        setNoCache r
    "DebugName" ->
      liftEwM $ do
        modifyIORef r (setLevel debugName)
        setNoCache r
    "DebugTry" ->
      liftEwM $ do
        modifyIORef r (setLevel debugTry)
        setNoCache r
    "DebugApplied" ->
      liftEwM $ do
        modifyIORef r (setLevel debugApplied)
        setNoCache r
    "DebugAll" ->
      liftEwM $ do
        modifyIORef r (setLevel debugAll)
        setNoCache r
    _ ->
      addWarn (s ++ " is an invalid debug level")
 where
  setLevel lvl opts =
    opts { _opt_debug = lvl }
=======
-- | Render a bool flag with given name and value unconditionally
renderNoArg :: String -> Bool -> [String]
renderNoArg flagNm value
  | value = ["-fclash-" <> flagNm]
  | otherwise = ["-fclash-no-" <> flagNm]

class KnownSymbol flag => ClashFlag flag where
  getFlags :: Proxy flag -> IORef ClashOpts -> [Flag IO]
  renderFlag :: Proxy flag -> ClashOpts -> [String]

flagName :: ClashFlag a => Proxy a -> String
flagName = ssymbolToString . ssymbolProxy

-- | See 'opt_renderEnums'
instance ClashFlag "render-enums" where
  getFlags p r =
    noArg p r (\v opts -> opts{opt_renderEnums = v})
>>>>>>> 24fdf1ba (f)

  renderFlag p opts
    | opt_renderEnums opts == opt_renderEnums defClashOpts = []
    | otherwise = renderNoArg (flagName p) (opt_renderEnums opts)

<<<<<<< HEAD
    Nothing ->
      addWarn (s ++ " is an invalid debug info")
 where
  setInfo info opts =
    opts { _opt_debug = (_opt_debug opts) { _dbg_transformationInfo = info } }

setNoCache :: IORef ClashOpts -> IO ()
setNoCache r = modifyIORef r (\c -> c {_opt_cachehdl = False})

setNoIDirCheck :: IORef ClashOpts -> IO ()
setNoIDirCheck r = modifyIORef r (\c -> c {_opt_checkIDir = False})
=======
-- | See 'opt_edalize'
instance ClashFlag "edalize" where
  getFlags p r =
    noArg p r (\v opts -> opts{opt_edalize = v})

  renderFlag p opts
    | opt_edalize opts == opt_renderEnums defClashOpts = []
    | otherwise = renderNoArg (flagName p) (opt_edalize opts)

-- -- | See 'opt_aggressiveXOptBB'
-- instance ClashFlag "aggressive-x-optimization-blackboxes" where
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_aggressiveXOptBB = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_aggressiveXOptBB opts)
>>>>>>> 24fdf1ba (f)

-- -- | See 'opt_aggressiveXOpt'
-- instance ClashFlag "aggressive-x-optimization" where
--   getFlags p = getBoolFlags p (\opts v -> pure opts{
--       opt_aggressiveXOpt = v
--     , opt_aggressiveXOptBB = v
--   })

<<<<<<< HEAD
setClear :: IORef ClashOpts -> IO ()
setClear r = modifyIORef r (\c -> c {_opt_clear = True})

setNoPrimWarn :: IORef ClashOpts -> IO ()
setNoPrimWarn r = modifyIORef r (\c -> c {_opt_primWarn = False})

setIntWidth :: IORef ClashOpts
            -> Int
            -> EwM IO ()
setIntWidth r n =
  if n == 32 || n == 64
     then liftEwM $ modifyIORef r (\c -> c {_opt_intWidth = n})
     else addWarn (show n ++ " is an invalid Int/Word/Integer bit-width. Allowed widths: 32, 64.")

setHdlDir :: IORef ClashOpts
          -> String
          -> EwM IO ()
setHdlDir r s = liftEwM $ modifyIORef r (\c -> c {_opt_hdlDir = Just s})

setHdlSyn :: IORef ClashOpts
          -> String
          -> EwM IO ()
setHdlSyn r s = case readMaybe s of
  Just hdlSyn -> liftEwM $ modifyIORef r (\c -> c {_opt_hdlSyn = hdlSyn})
  Nothing -> case s of
    "Xilinx"  -> liftEwM $ modifyIORef r (\c -> c {_opt_hdlSyn = Vivado})
    "ISE"     -> liftEwM $ modifyIORef r (\c -> c {_opt_hdlSyn = Vivado})
    "Altera"  -> liftEwM $ modifyIORef r (\c -> c {_opt_hdlSyn = Quartus})
    "Intel"   -> liftEwM $ modifyIORef r (\c -> c {_opt_hdlSyn = Quartus})
    _         -> addWarn (s ++ " is an unknown hdl synthesis tool")

setErrorExtra :: IORef ClashOpts -> IO ()
setErrorExtra r = modifyIORef r (\c -> c {_opt_errorExtra = True})
=======
--   renderFlag p opts = maybeRenderBoolFlag p (opt_aggressiveXOpt opts)

-- -- | See 'opt_checkIDir'
-- instance ClashFlag "check-inaccessible-idirs" where
--   type ClashFlagValue "check-inaccessible-idirs" = Bool

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_checkIDir = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_checkIDir opts)

-- -- | See 'opt_ultra'
-- instance ClashFlag "compile-ultra" where
--   type ClashFlagValue "compile-ultra" = Bool

--   flagDefault _ = False
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_ultra = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_ultra opts)

-- -- | See 'opt_escapedIds'
-- instance ClashFlag "escaped-identifiers" where
--   type ClashFlagValue "escaped-identifiers" = Bool
>>>>>>> 24fdf1ba (f)

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_escapedIds = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_escapedIds opts)

<<<<<<< HEAD
setComponentPrefix
  :: IORef ClashOpts
  -> String
  -> IO ()
setComponentPrefix r s =
  modifyIORef r (\c -> c {_opt_componentPrefix = Just (Text.pack s)})

setOldInlineStrategy :: IORef ClashOpts -> IO ()
setOldInlineStrategy r = modifyIORef r (\c -> c {_opt_newInlineStrat = False})

setNoEscapedIds :: IORef ClashOpts -> IO ()
setNoEscapedIds r = modifyIORef r (\c -> c {_opt_escapedIds = False})

setLowerCaseBasicIds :: IORef ClashOpts -> IO ()
setLowerCaseBasicIds r = modifyIORef r (\c -> c {_opt_lowerCaseBasicIds = ToLower})

setUltra :: IORef ClashOpts -> IO ()
setUltra r = modifyIORef r (\c -> c {_opt_ultra = True})

setUndefined :: IORef ClashOpts -> Maybe Int -> EwM IO ()
setUndefined _ (Just x) | x < 0 || x > 1 =
  addWarn ("-fclash-force-undefined=" ++ show x ++ " ignored, " ++ show x ++
           " not in range [0,1]")
setUndefined r iM =
  liftEwM (modifyIORef r (\c -> c {_opt_forceUndefined = Just iM}))

setAggressiveXOpt :: IORef ClashOpts -> IO ()
setAggressiveXOpt r = do
  modifyIORef r (\c -> c { _opt_aggressiveXOpt = True })
  setAggressiveXOptBB r


setAggressiveXOptBB :: IORef ClashOpts -> IO ()
setAggressiveXOptBB r = modifyIORef r (\c -> c { _opt_aggressiveXOptBB = True })

setEdalize :: IORef ClashOpts -> IO ()
setEdalize r = modifyIORef r (\c -> c { _opt_edalize = True })

setRewriteHistoryFile :: IORef ClashOpts -> String -> IO ()
setRewriteHistoryFile r arg = do
  let fileNm = case drop (length "-fclash-debug-history=") arg of
                [] -> "history.dat"
                str -> str
  modifyIORef r (setFile fileNm)
 where
  setFile file opts =
    opts { _opt_debug = (_opt_debug opts) { _dbg_historyFile = Just file } }

setNoRenderEnums :: IORef ClashOpts -> IO ()
setNoRenderEnums r = modifyIORef r (\c -> c { _opt_renderEnums = False })
=======
-- -- | See 'opt_newInlineStrat'
-- instance ClashFlag "old-inline-strategy" where
--   type ClashFlagValue "old-inline-strategy" = Bool

--   flagDefault _ = False
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_newInlineStrat = not v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_newInlineStrat opts)

-- -- | See 'opt_errorExtra'
-- instance ClashFlag "error-extra" where
--   type ClashFlagValue "error-extra" = Bool

--   flagDefault _ = False
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_errorExtra = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_errorExtra opts)

-- -- | See 'opt_cachehdl'
-- instance ClashFlag "cache" where
--   type ClashFlagValue "cache" = Bool

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_cachehdl = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_cachehdl opts)

-- -- | See 'opt_cachehdl'
-- instance ClashFlag "nocache" where
--   type ClashFlagValue "nocache" = Bool

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_cachehdl = not v})
--   renderFlag _proxy = pure []  -- flag deprecated in favor or 'cache'

-- -- | See 'opt_clear'
-- instance ClashFlag "clear" where
--   type ClashFlagValue "clear" = Bool

--   flagDefault _ = False
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_clear = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_clear opts)

-- -- | See 'opt_primWarn'
-- instance ClashFlag "prim-warn" where
--   type ClashFlagValue "prim-warn" = Bool

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts v -> pure opts{opt_primWarn = v})
--   renderFlag p opts = maybeRenderBoolFlag p (opt_primWarn opts)

-- -- | See 'opt_lowerCaseBasicIds'
-- instance ClashFlag "lower-case-basic-identifiers" where
--   type ClashFlagValue "lower-case-basic-identifiers" = Bool

--   flagDefault _ = True

--   getFlags p =
--     getBoolFlags p $ \opts v ->
--       pure opts{opt_lowerCaseBasicIds = if v then ToLower else PreserveCase}

--   renderFlag p opts = maybeRenderBoolFlag p (toBool (opt_lowerCaseBasicIds opts))
--    where
--     toBool ToLower = True
--     toBool PreserveCase = False

-- -- | See 'dbg_countTransformations'
-- instance ClashFlag "debug-count-transformations" where
--   type ClashFlagValue "debug-count-transformations" = Bool

--   flagDefault _ = True
--   getFlags p =
--     getBoolFlags p $ \opts v ->
--       pure opts{opt_debug = (opt_debug opts){ dbg_countTransformations = v }}
--   renderFlag p opts = maybeRenderBoolFlag p (dbg_countTransformations (opt_debug opts))

-- -- | See 'dbg_invariants'
-- instance ClashFlag "debug-invariants" where
--   type ClashFlagValue "debug-invariants" = Bool

--   flagDefault _ = True
--   getFlags p =
--     getBoolFlags p $ \opts v ->
--       pure opts{opt_debug = (opt_debug opts){ dbg_invariants = v }}
--   renderFlag p opts = maybeRenderBoolFlag p (dbg_invariants (opt_debug opts))

-- -- | This flag has been removed
-- instance ClashFlag "clean" where
--   type ClashFlagValue "clean" = Bool

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts v -> pure opts)
--   renderFlag _ _ = []

-- -- | This flag has been removed
-- instance ClashFlag "float-support" where
--   type ClashFlagValue "float-support" = Bool

--   flagDefault _ = True
--   getFlags p = getBoolFlags p (\opts _ -> pure opts)
--   renderFlag _ _ = pure []

-- -- | See 'opt_inlineLimit'
-- instance ClashFlag "inline-limit" where
--   type ClashFlagValue "inline-limit" = Int

--   flagDefault _ = 20
--   getFlags p = getIntFlags p $ \opts v -> pure opts{opt_inlineLimit = v}
--   renderFlag p opts = maybeRenderArgFlag p (opt_inlineLimit opts)

-- -- | See 'opt_specLimit'
-- instance ClashFlag "spec-limit" where
--   type ClashFlagValue "spec-limit" = Int

--   flagDefault _ = 20
--   getFlags p = getIntFlags p $ \opts v -> pure opts{opt_specLimit = v}
--   renderFlag p opts = maybeRenderArgFlag p (opt_specLimit opts)

-- -- | See 'opt_inlineFunctionLimit'
-- instance ClashFlag "inline-function-limit" where
--   type ClashFlagValue "inline-function-limit" = Word

--   flagDefault _ = 15
--   getFlags p = getWordFlags p $ \opts v -> pure opts{opt_inlineFunctionLimit = v}
--   renderFlag p opts = maybeRenderArgFlag p (opt_inlineFunctionLimit opts)

-- -- | See 'opt_inlineConstantLimit'
-- instance ClashFlag "inline-constant-limit" where
--   type ClashFlagValue "inline-constant-limit" = Word

--   flagDefault _ = 0
--   getFlags p = getWordFlags p $ \opts v -> pure opts{opt_inlineConstantLimit = v}
--   renderFlag p opts = maybeRenderArgFlag p (opt_inlineConstantLimit opts)

-- -- | See 'opt_evaluatorFuelLimit'
-- instance ClashFlag "evaluator-fuel-limit" where
--   type ClashFlagValue "evaluator-fuel-limit" = Word

--   flagDefault _ = 20
--   getFlags p = getWordFlags p $ \opts v -> pure opts{opt_evaluatorFuelLimit = v}
--   renderFlag p opts = maybeRenderArgFlag p (opt_evaluatorFuelLimit opts)

-- -- | See 'opt_inlineWFCacheLimit'
-- instance ClashFlag "inline-workfree-limit" where
--   type ClashFlagValue "inline-workfree-limit" = Word

--   flagDefault _ = 10
--   getFlags p = getWordFlags p $ \opts v -> pure opts{opt_inlineWFCacheLimit = v}
--   renderFlag p opts = maybeRenderArgFlag p (opt_inlineWFCacheLimit opts)

-- -- | See 'dbg_transformationsFrom'
-- instance ClashFlag "debug-transformations-from" where
--   type ClashFlagValue "debug-transformations-from" = Maybe Word

--   flagDefault _ = Nothing
--   getFlags p = do
--     wordFlags <- getWordFlags p $ \opts v -> setFlag opts (Just v)
--     unsetFlag <- getUnsetFlag p $ \opts _ -> setFlag opts Nothing
--     pure (unsetFlag : wordFlags)
--    where
--     setFlag opts v =
--       pure opts{opt_debug = (opt_debug opts){dbg_transformationsFrom = v}}

--   renderFlag p opts =
--     case dbg_transformationsFrom (opt_debug opts) of
--       Nothing -> []
--       Just v -> renderArgFlag (flagName p) v

-- -- | See 'dbg_transformationsLimit'
-- instance ClashFlag "debug-transformations-limit" where
--   type ClashFlagValue "debug-transformations-limit" = Maybe Word

--   flagDefault _ = maxBound

--   getFlags p = do
--     wordFlags <- getWordFlags p $ \opts v -> setFlag opts (Just v)
--     unsetFlag <- getUnsetFlag p $ \opts _ -> setFlag opts Nothing
--     pure (unsetFlag : wordFlags)
--    where
--     setFlag opts v =
--       pure opts{opt_debug = (opt_debug opts){dbg_transformationsLimit = v}}

--   renderFlag p opts =
--     case dbg_transformationsLimit (opt_debug opts) of
--       Nothing -> []
--       Just v -> renderArgFlag (flagName p) v

-- -- | See 'opt_intWidth'
-- instance ClashFlag "intwidth" where
--   type ClashFlagValue "intwidth" = Int

--   flagDefault _ = WORD_SIZE_IN_BITS

--   getFlags p =
--     getIntFlags p $ \opts v -> do
--       unless (v == 32 || v == 64) $ do
--         addErr ("intwidth should be 32 or 64, not: " <> show v)
--       pure opts{ opt_intWidth = v }

--   renderFlag p opts = maybeRenderArgFlag p (opt_intWidth opts)

-- -- | See 'dbg_transformations'
-- instance ClashFlag "debug-transformations" where
--   type ClashFlagValue "debug-transformations" = Set String

--   flagDefault _ = mempty

--   getFlags p =
--     getSetFlags p $ \opts v ->
--       pure opts{opt_debug = (opt_debug opts){dbg_transformations = v}}

--   renderFlag p opts =
--     maybeRenderArgFlagWith showSet p transformations
--    where
--     showSet = intercalate "," . Set.elems
--     transformations = dbg_transformations (opt_debug opts)

-- -- | Meta flag: covers various flags in 'opt_debug'
-- instance ClashFlag "debug" where
--   type ClashFlagValue "debug" = String

--   flagDefault _ = mempty
--   getFlags p = getStringFlags p setDebugLevel
--   renderFlag _proxy = pure []

-- -- | See 'dbg_transformationInfo'
-- instance ClashFlag "debug-info" where
--   type ClashFlagValue "debug-info" = TransformationInfo

--   flagDefault _ = mempty
--   getFlags p =
--     getReadableFlags p $ \opts v ->
--       opts{opt_debug = (opt_debug opts){dbg_transformationInfo = v}}
--   renderFlag = renderShowableFlags

-- -- | See 'dbg_historyFile'
-- instance ClashFlag "debug-history" where
--   type ClashFlagValue "debug-history" = Maybe FilePath

--   flagDefault _ = mempty
--   getFlags p = do
--     stringFlags <- getStringFlags p $ \opts v -> setFlag opts (Just v)
--     unsetFlag <- getUnsetFlag p $ \opts _ -> setFlag opts Nothing
--     pure (unsetFlag : stringFlags)
--    where
--     setFlag opts v = pure opts{opt_debug = (opt_debug opts){dbg_historyFile = v}}

--   renderFlag = renderGhcMaybeStringFlag

-- -- | See 'opt_hdlDir'
-- instance ClashFlag "hdldir" where
--   type ClashFlagValue "hdldir" = Maybe String

--   flagDefault _ = Nothing

--   getFlags p =  do
--     stringFlags <- getStringFlags p $ \opts v -> setFlag opts (Just v)
--     unsetFlag <- getUnsetFlag p $ \opts _ -> setFlag opts Nothing
--     pure (unsetFlag : stringFlags)
--    where
--     setFlag opts v = pure opts{opt_hdlDir = v}

--   renderFlag = renderGhcMaybeStringFlag

-- -- | See 'opt_componentPrefix'
-- instance ClashFlag "component-prefix" where
--   type ClashFlagValue "component-prefix" = Maybe Text

--   flagDefault _ = Nothing

--   getFlags p = do
--     textFlags <- getTextFlags p $ \opts v -> setFlag opts (Just v)
--     unsetFlag <- getUnsetFlag p $ \opts _ -> setFlag opts Nothing
--     pure (unsetFlag : textFlags)
--    where
--     setFlag opts v = pure opts{opt_componentPrefix = v}

--   renderFlag = renderGhcMaybeTextFlag

-- -- | See 'opt_forceUndefined'
-- instance ClashFlag "force-undefined" where
--   type ClashFlagValue "force-undefined" = Maybe Int

--   flagDefault _ = Nothing

--   getFlags p = do
--     intFlags <- getIntFlags p $ \opts v -> setFlag opts (Just (Just v))
--     unsetFlag <- getUnsetFlag p $ \opts _ -> setFlag opts Nothing
--     pure (unsetFlag : intFlags)
--    where
--     setFlag opts v = pure opts{opt_forceUndefined = v}

--   renderFlag = renderGhcMaybeStringFlag

-- -- | See 'opt_hdlSyn'
-- instance ClashFlag "hdlsyn" where
--   type ClashFlagValue "hdlsyn" = String

--   flagDefault _ = "Other"
--   getFlags p = error "NIY"
--   renderFlag = renderGhcStringFlag


-- setDebugLevel :: ClashOpts -> String -> EwM IO ClashOpts
-- setDebugLevel opts s =
--   case s of
--     "DebugNone" -> pure opts{ opt_debug = debugNone }
--     "DebugSilent" -> setLevel debugSilent
--     "DebugFinal" -> setLevel debugFinal
--     "DebugCount" -> setLevel debugCount
--     "DebugName" -> setLevel debugName
--     "DebugTry" -> setLevel debugTry
--     "DebugApplied" -> setLevel debugApplied
--     "DebugAll" -> setLevel debugAll
--     _ -> do
--       addErr (s ++ " is an invalid debug level")
--       pure opts
--  where
--   setLevel lvl = pure opts{
--       opt_debug = lvl
--     , opt_cachehdl = False
--   }
>>>>>>> 24fdf1ba (f)
