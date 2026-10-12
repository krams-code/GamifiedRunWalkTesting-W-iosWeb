# Lottie effects generator

The 8 animations in `assets/animations/lottie/` are drawn in code.

    python3 gen.py        # writes out/*.json  -> copy into assets/animations/lottie/
    python3 render.py     # (optional) preview strips via headless Chromium + lottie-web

Edit colours, timing and shapes in `gen.py` (frames are 30 fps). Each function returns one animation.
Use them in Flutter through `lib/widgets/lottie_fx.dart` (`Fx.*`, `FxOnce`, `FxLoop`, `FxBehind`, `LevelUpBurst`, `LoadingRunner`).
