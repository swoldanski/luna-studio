---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------

import           Data.List                       as List
import           Options.Applicative             hiding (info)
import qualified Options.Applicative             as Opt

import           Flowbox.Prelude                 hiding (error)
import qualified Flowbox.Config.Config           as Config
import           Flowbox.Config.Config             (Config)
import           Flowbox.Control.Applicative       
import qualified Flowbox.Data.Version            as Version
import           Flowbox.Data.Version              (Version)
import qualified Flowbox.Initializer.Initializer as Initializer
import qualified Flowbox.Lunac.Builder           as Builder
import qualified Flowbox.Lunac.CmdArgs           as CmdArgs
import           Flowbox.Lunac.CmdArgs             (CmdArgs)
import           Flowbox.Lunac.Diagnostics         (Diagnostics(Diagnostics))
import           Flowbox.System.Log.Logger         
import qualified Flowbox.System.UniPath          as UniPath



rootLogger :: Logger
rootLogger = getLogger "Flowbox"


--logger :: Logger
--logger = getLogger "Flowbox.Lunac"


--libPathEnv :: String
--libPathEnv = "LUNAPATH"


parser :: Parser CmdArgs
parser = Opt.flag' CmdArgs.Version (long "version" <> hidden)
       <|> CmdArgs.Compilation
           <$> many1     ( argument str ( metavar "inputs" ))
           <*> many      ( strOption ( short 'l' <> metavar "LIBRARY" <> help "Library to link with.")                 )
           <*> strOption ( long "output"  <> short 'o' <> value "out"     <> metavar "OUTPUT"  <> help "Output folder" )
           <*> strOption ( long "name"    <> short 'n' <> value "name"    <> metavar "NAME"    <> help "Project name"  )
           <*> strOption ( long "root-path"            <> value ""        <> hidden                                    )
       
           <*> switch    ( long "global"                         <> help "Enable to compile to global cabal repository")
           <*> switch    ( long "library"                        <> help "Enable to compile as a library"              )
       
           <*> switch    ( long "verbose" <> short 'v'           <> help "Verbose level"                               )
           <*> switch    ( long "no-color"                       <> help "Disable color output"                        )

           <*> switch    ( long "dump-all"              <> hidden                                                      )
           <*> switch    ( long "dump-ast"              <> hidden                                                      )
           <*> switch    ( long "dump-va"               <> hidden                                                      )
           <*> switch    ( long "dump-fp"               <> hidden                                                      )
           <*> switch    ( long "dump-ssa"              <> hidden                                                      )
           <*> switch    ( long "dump-hast"             <> hidden                                                      )
           <*> switch    ( long "dump-hsc"              <> hidden                                                      )


opts :: Config -> ParserInfo CmdArgs
opts cfg = Opt.info (helper <*> parser)
              (Opt.fullDesc
                  <> Opt.header (show_version cfg)
              )


show_version :: Config -> String
show_version cfg = "Luna compiler, version " ++ Version.str (Config.version cfg)


main :: IO ()
main = do
    cfg <- Config.load
    execParser (opts cfg) >>= (run cfg)


run :: Config -> CmdArgs -> IO ()
run cfg cmd = do
    case cmd of
        CmdArgs.Version     {} -> putStrLn $ show_version cfg
        CmdArgs.Compilation {} -> do
            if CmdArgs.verbose cmd
                then rootLogger setLevel DEBUG
                else rootLogger setLevel INFO

            let diag = Diagnostics ( CmdArgs.dump_ast  cmd || CmdArgs.dump_all cmd )
                                   ( CmdArgs.dump_va   cmd || CmdArgs.dump_all cmd )
                                   ( CmdArgs.dump_fp   cmd || CmdArgs.dump_all cmd )
                                   ( CmdArgs.dump_ssa  cmd || CmdArgs.dump_all cmd )
                                   ( CmdArgs.dump_hast cmd || CmdArgs.dump_all cmd )
                                   ( CmdArgs.dump_hsc  cmd || CmdArgs.dump_all cmd )

                inputs = map UniPath.fromUnixString $ CmdArgs.inputs cmd


            Initializer.initializeIfNeeded cfg

            mapM_ (Builder.buildFile cfg cmd diag) inputs
      

