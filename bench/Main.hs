{-# LANGUAGE BangPatterns #-}

module Main where

import qualified Control.Concurrent as C
import qualified Control.Concurrent.Chan.Unagi as U
import qualified Control.Concurrent.Chan.Unagi.Unboxed as UU
import qualified Control.Concurrent.Chan.Unagi.Bounded as UB
import qualified Control.Concurrent.Chan.Unagi.NoBlocking as UN
import qualified Control.Concurrent.Chan.Unagi.NoBlocking as UNU
import qualified Data.IORef as IOR

import Control.Concurrent.Async
import Control.Monad
import Criterion.Main
import GHC.Conc


main :: IO ()
main = do 
  -- usually 100,000
  let n = 100000

  procs <- getNumCapabilities
  unless (even procs) $
    error "Please run with +RTS -NX, where X is an even number"
  let procs_div2 = procs `div` 2
  if procs_div2 >= 0 then return ()
                     else error "Run with RTS +N2 or more"

  putStrLn $ "Running with capabilities: " ++ (show procs)

  defaultMain $
    [ bgroup ("Operations on " ++ (show n) ++ " messages") $
        [ bgroup "unagi-chan Unagi broadcast" $
              -- this gives us a measure of effects of contention between
              -- readers and writers when compared with single-threaded
              -- version:
              [ bench "1 writer, 10 readers" $ nfIO $ unagiBroadcast 1 10 n
              , bench "1 writer, 100 readers" $ nfIO $ unagiBroadcast 1 100 n
              , bench "1 writer, 10000 readers" $ nfIO $ unagiBroadcast 1 10000 n
              ]
        ]
    ]

-- ubReader i readerCount = do
--   o <- U.dupChan i
--   async $ replicateM_ readerCount $ do
--     U.readChan o

unagiBroadcast :: Int -> Int -> Int -> IO ()
unagiBroadcast writers readers n = do
  let nNice = n - rem n (lcm writers readers)
      readerCount = nNice `quot` readers
      writerCount = nNice `quot` writers
  (i,o) <- U.newChan
  -- async $ forever $ U.readChan o
  -- rcvrs <- replicateM readers $ async $ replicateM_ readerCount $ U.dupChan i >>= U.readChan
  rcvrs <- replicateM readers $ async $ replicateM_ readerCount $ U.dupChan i >>= U.readChan
  -- rcvrs <- replicateM readers $ ubReader i readerCount
  _ <- replicateM writers $ async $ replicateM_ writerCount $ U.writeChan i ()
  mapM_ wait rcvrs


  -- counter <- IOR.newIORef 0

  -- finalValue <- IOR.readIORef counter
  -- putStrLn $ "FINAL VALUE WAS: " ++ show finalValue

  -- rcvrs <- replicateM readers $ async $ U.dupChan i >>= U.readChan
  -- rcvrs <- replicateM readers $ async $ replicateM_ (nNice `quot` readers) $ (U.readChan o)
  -- rcvrs <- replicateM readers $ async $ replicateM_ (nNice `quot` readers) $ U.dupChan i >>= ubReader counter
  -- rcvrs <- replicateM readers $ async $ replicateM_ (nNice `quot` readers) $ U.readChan o

-- ubReader :: IOR.IORef Int -> U.OutChan () -> IO ()
-- ubReader ior o = do
--   () <- U.readChan o
--   IOR.atomicModifyIORef ior (\a -> (a+1, ()))
