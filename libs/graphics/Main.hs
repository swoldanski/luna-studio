---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE TypeOperators             #-}

{-# LANGUAGE CPP                       #-}
-- {-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE ExtendedDefaultRules      #-}


import qualified Config                as Cfg
import           Control.Applicative
import qualified Data.Array.Accelerate as A
import qualified Data.Array.Accelerate.CUDA as CUDA
import qualified Data.Array.Accelerate.Interpreter as Interp
import qualified Data.Label            as Label
--import qualified Debug.Trace           as Dbg
import qualified Monitoring            as Monitoring
import qualified ParseArgs             as ParseArgs
import qualified System.Environment    as Env
import qualified System.Exit           as Exit
import qualified Text.Printf           as T

import qualified Flowbox.Graphics.Algorithms       as G
import           Flowbox.Graphics.Color            (Color (..))
import qualified Flowbox.Graphics.Color            as C
import           Flowbox.Graphics.Raster.Channel   (Channel, Channel2, Channel3, RawData2D, RawData3D)
import qualified Flowbox.Graphics.Raster.Channel   as Channel
import           Flowbox.Graphics.Raster.Image     (Image)
import qualified Flowbox.Graphics.Raster.Image     as Image
import qualified Flowbox.Graphics.Raster.IO        as Image
import qualified Flowbox.Graphics.Raster.Repr.RGBA as RGBA
import           Flowbox.Prelude                   as P


----imgtest :: Image A.Word32 -> Either Image.Error (Image A.Word32)
imgtest img frames = do
    let getDouble image = Image.reprDouble <$> RGBA.decompose image
        rgb = ("r", "g", "b")

    imageRGBA <- getDouble img
    framesRGBA <- getDouble frames

    --imageBackground <- G.extractBackground rgb framesRGBA
    let imageConstant = Image.constant (A.index2 256 256) [("r", A.constant 1), ("g", A.constant 0), ("b", A.constant 1), ("a", A.constant 1)]

    let imageOut = imageConstant
    RGBA.compose $ Image.reprWord8 $ Image.map G.clipValues imageOut

---- main

main :: IO ()
main
  = do
        Monitoring.beginMonitoring

        argv                    <- Env.getArgs
        (conf, cconf, nops)     <- ParseArgs.parseArgs Cfg.configHelp Cfg.configBackend Cfg.options Cfg.defaults Cfg.header Cfg.footer argv
        (fileIn, fileOut)       <- case nops of
          (i:o:_) -> return (i,o)
          _       -> ParseArgs.parseArgs Cfg.configHelp Cfg.configBackend Cfg.options Cfg.defaults Cfg.header Cfg.footer ("--help":argv)
                  >> Exit.exitSuccess

        let backend     = ParseArgs.Interpreter --Label.get Cfg.configBackend conf
            frameNames  = replicate 5 "lena.bmp"
            --frameNames  = fmap (\x -> (T.printf "frames/frame-small-%03d.bmp" x) :: String) ([1,5..66] :: [Int])
            getImage location = fmap (either (\_ -> mempty) id) (Image.readImageFromBMP location)
            getImages locations = fmap (either (\_ -> mempty) id) (Image.readImageSequenceFromBMP locations)
            getDouble image = Image.reprFloat <$> RGBA.decompose image

        -- Read in the image file
        imageIn <- getImage fileIn
        framesIn <- getImages frameNames

        let imageOut = imgtest imageIn framesIn

        case imageOut of
            Left err -> print err
            Right val -> do Image.writeImageToBMP (ParseArgs.run backend) fileOut val
                            return ()


        -- COLOR TESTS

        let x = 0.5 :: A.Exp Double
            y = 0.3 :: A.Exp Double
            z = 0.2 :: A.Exp Double
            rgb  = RGB x y z
            rgba = C.toRGBA rgb
            hsv  = C.toHSV rgba
            hsl  = C.toHSL hsv
            cmy  = C.toCMY hsl
            cmyk = C.toCMYK cmy
            rgb' = C.toRGB cmyk
            (RGB r g b) = rgb'

        print $ Interp.run $ A.unit $ A.lift (r, g, b)


        --if P.not (Label.get Cfg.configBenchmark conf)
        --   then do
        --     -- Connect the strong and weak edges of the image using Repa, and
        --     -- write the final image to file
        --     --
        --     --let (image, strong) = ParseArgs.run backend $ A.lift (Canny.canny threshLow threshHigh (A.use img))
        --     --edges              <- Wildfire.wildfire (A.toRepa image) (A.toRepa strong)
        --     --R.writeImageToBMP fileOut (R.zip3 edges edges edges)


        --         --print "!!!1"
        --         ---- Connect the strong and weak edges of the image using Repa, and
        --         ---- write the final image to file
        --         ----
        --         --print "1"
        --         --let (image, strong) = ParseArgs.run backend $ A.lift (Canny.canny threshLow threshHigh (A.use img))
        --         --print "2"
        --     --let test            = A.toRepa ltest -- :: Int -- R.Array R.U R.DIM2 Word8
        --     --    ----print (test `R.deepSeq` "#2")
        --     --    --print "3"
        --     --test2 <- timeIt (demote2 test :: IO (R.Array R.U R.DIM2 Word8))
        --         --print "4"
        --         ----edges              <- Wildfire.wildfire (A.toRepa image) (A.toRepa strong)
        --         --print "write"
        --     --timeIt $ R.writeImageToBMP fileOut (R.zip3 test2 test2 test2)
        --     return ()

        --  else do
        --    -- Run each of the individual kernel stages through criterion, as
        --    -- well as the end-to-end step process.
        --    --
        --    Env.withArgs (P.drop 2 nops) $ defaultMainWith cconf (return ())
        --      [ bgroup "kernels"
        --        [   --  bench "normalize"   $ whnf normalizeRGBA32 img
        --            --, bench "demote"      $ (demote test :: IO (R.Array R.U R.DIM2 Word8))
        --            --, bench "file read"   $ either (error . show) id `fmap` A.readImageFromBMP fileIn
        --            --, bench "greyscale"   $ whnf ((ParseArgs.run backend) . Canny.toGreyscale) (A.use img)
        --            --, bench "cos"         $ whnf (\img' -> ParseArgs.run backend $ A.lift (Canny.canny threshLow threshHigh (A.use img'))) img
        --            --, bench "toRepa"      $ whnf (A.toRepa) grey'
        --            --, bench "write"       $ R.writeImageToBMP fileOut (R.zip3 test2 test2 test2)
        --        ]

        --      ]

        --    --Env.withArgs (P.drop 2 nops) $ defaultMainWith cconf (return ())
        --    --  [ bgroup "kernels"
        --    --    [ bench "greyscale"   $ whnf (ParseArgs.run1 backend Canny.toGreyscale) img
        --    --    , bench "blur-x"      $ whnf (ParseArgs.run1 backend Canny.gaussianX) grey'
        --    --    , bench "blur-y"      $ whnf (ParseArgs.run1 backend Canny.gaussianY) blurX'
        --    --    , bench "grad-x"      $ whnf (ParseArgs.run1 backend Canny.gradientX) blurred'
        --    --    , bench "grad-y"      $ whnf (ParseArgs.run1 backend Canny.gradientY) blurred'
        --    --    , bench "mag-orient"  $ whnf (ParseArgs.run1 backend (Canny.gradientMagDir low)) blurred'
        --    --    , bench "suppress"    $ whnf (ParseArgs.run1 backend (Canny.nonMaximumSuppression low high)) magdir'
        --    --    , bench "select"      $ whnf (ParseArgs.run1 backend Canny.selectStrong) suppress'
        --    --    ]

        --    --  , bgroup "canny"
        --    --    [ bench "run"     $ whnf (ParseArgs.run backend . (P.snd . Canny.canny threshLow threshHigh)) (A.use img)
        --    --    , bench "run1"    $ whnf (ParseArgs.run1 backend  (P.snd . Canny.canny threshLow threshHigh)) img
        --    --    ]
        --    --  ]

