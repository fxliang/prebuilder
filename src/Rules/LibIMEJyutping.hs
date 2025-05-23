module Rules.LibIMEJyutping (libIMEJyutpingRule) where

import Base

libIMEJyutpingRule :: Rules ()
libIMEJyutpingRule = do
  jyutpingToolsRule
  jyutpingDictRule
  jyutpingLmRule
  "libime-jyutping" ~> do
    copyFile' (outputDir </> "jyutping.dict") $ outputDir </> "libime-jyutping" </> "jyutping.dict"
    copyFile' (outputDir </> "zh_HK.lm") $ outputDir </> "libime-jyutping" </> "zh_HK.lm"
    copyFile' (outputDir </> "zh_HK.lm.predict") $ outputDir </> "libime-jyutping" </> "zh_HK.lm.predict"

jyutpingToolsRule :: Rules ()
jyutpingToolsRule = do
  "libime-jyutping-tools" ~> do
    need ["libime-tools"]
    let libIMEJyutpingSrc = "libime-jyutping"
    let buildDir = outputDir </> "libime-jyutping-build-host"
    let hostPrefix = outputDir </> "host"
    cmd_
      "cmake"
      "-B"
      buildDir
      "-G"
      "Ninja"
      [ "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_PREFIX=" <> hostPrefix,
        "-DCMAKE_FIND_ROOT_PATH=" <> hostPrefix,  -- for find_package
        "-DCMAKE_PREFIX_PATH=" <> hostPrefix,     -- for pkg_check_modules
        "-DENABLE_TEST=OFF",
        "-DENABLE_ENGINE=OFF"
      ]
      libIMEJyutpingSrc
    cmd_ "cmake" "--build" buildDir "--target" "libime_jyutpingdict"
    -- ignore install errors
    Exit _ <- cmd "cmake" "--install" buildDir "--component" "lib"
    Exit _ <- cmd "cmake" "--install" buildDir "--component" "tools"
    pure ()

jyutpingDictRule :: Rules ()
jyutpingDictRule = do
  outputDir </> "words.txt" %> \out -> do
    src <- getConfig' "jyutping_dict"
    sha256 <- getConfig' "jyutping_dict_sha256"
    fcitxDataUrl <- getConfig' "fcitx_data_url"
    tar <- download fcitxDataUrl src sha256
    cmd_ "tar" "xf" tar "-C" outputDir (takeFileName out)
  outputDir </> "jyutping.dict" %> \out -> do
    let src = outputDir </> "words.txt"
    need ["libime-jyutping-tools", src]
    execute "libime_jyutpingdict" src out

jyutpingLmRule :: Rules ()
jyutpingLmRule = do
  outputDir </> "hk.arpa" %> \out -> do
    src <- getConfig' "jyutping_model"
    sha256 <- getConfig' "jyutping_model_sha256"
    fcitxDataUrl <- getConfig' "fcitx_data_url"
    tar <- download fcitxDataUrl src sha256
    cmd_ "tar" "xf" tar "-C" outputDir (takeFileName out)
  outputDir </> "zh_HK.lm" %> \out -> do
    let src = outputDir </> "hk.arpa"
    need ["libime-tools", src]
    execute "libime_slm_build_binary" "-s -a 22 -q 8 trie" src out
  outputDir </> "zh_HK.lm.predict" %> \out -> do
    let src1 = outputDir </> "zh_HK.lm"
        src2 = outputDir </> "hk.arpa"
    need ["libime-tools", src1, src2]
    execute "libime_prediction" src1 src2 out
