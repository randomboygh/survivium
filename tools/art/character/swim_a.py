"""The swim, variant A (breaststroke): reach in, sweep out from the shoulders, pull down,
recover; the legs glide, kick apart, draw up. Box rows 10-17."""
E = ".............."
SWIM = {
    "s": (0, [
        [E, "...ccVkkVcc...", "...cC4477Cc...", "....c5588c....", "....UUuuUU....", "....TT..TT....", "....tt..tt....", "....BB..BB...."],
        [E, "....cVkkVc....", ".45ccCCCCcc87.", ".45.cCCCCc.87.", "....UUuuUU....", "...TT....TT...", "...tt....tt...", "...BB....BB..."],
        [E, "....cVkkVc....", "...ccCCCCcc...", "..45cCCCCc87..", "..45UUuuUU87..", "...TT....TT...", "...BB....BB...", E],
        [E, "...ccVkkVcc...", "...44CCCC77...", "...55cCCc88...", "....UUuuUU....", "....TT..TT....", "....tt..tt....", "....BB..BB...."],
    ]),
    "se": (1, [
        [E, E, ".....VkkVc....", "....44CC77....", "....55cC88....", ".....UUuUU....", ".....TT.Tt....", ".....KB.KB...."],
        [E, E, ".....VkkVc88..", "..44ccCCC.88..", "..44.cCCC.....", ".....UUuUU....", "....TT...Tt...", "....KB...KB..."],
        [E, E, ".....VkkVc....", "....ccCCC88...", "...44cCCC88...", "...44UUuUU....", "....KB...KB...", E],
        [E, E, ".....VkkVc....", "....44CCC77...", "....55cCC88...", ".....UUuUU....", ".....TT.Tt....", ".....KB.KB...."],
    ]),
    "e": (0, [
        [E, "......CVk.....", ".....cCC444...", "...uUUu.555...", "...TTm........", "..BBb.........", E, E],
        [E, "......CVk.....", ".....cC44.....", "...uUUu44.....", "...tTm........", "..bBb.........", E, E],
        [E, "......CVk.....", "....44CCc.....", "..44UUu.......", "...mTT........", "...bBB........", E, E],
        [E, "......CV44....", ".....cCC44....", "...uUUu.......", "...mTt........", "..bBb.........", E, E],
    ]),
    "ne": (1, [
        [E, E, "....cVVVCC....", "....ccccCCC...", ".....VcccC....", ".....uuuuu....", ".....mm.tt....", ".....bb.BB...."],
        [E, E, ".....VVVC.....", "..88ccccCCC44.", "..88.VcccC.44.", ".....uuuuu....", "....mm...tt...", "....bb...BB..."],
        [E, E, ".....VVVC.....", "....ccccCCC...", "...88VcccC44..", "...88uuuuu44..", "....bb...BB...", E],
        [E, E, "....8VVVC4....", "....8cccCC4...", ".....VcccC....", ".....uuuuu....", ".....mm.tt....", ".....bb.BB...."],
    ]),
    "n": (1, [
        [E, "...C......C...", "...CCVVVVCC...", "...CCccccCC...", "....CccccC....", "....uuuuuu....", "....mm..mm....", "....bb..bb...."],
        [E, E, "...CCVVVVCC...", ".77CCccccCC44.", ".88.CccccC.55.", "....uuuuuu....", "...mm....mm...", "...bb....bb..."],
        [E, E, "...CCVVVVCC...", "..77CccccC44..", "..77CccccC44..", "..88uuuuuu55..", "...bb....bb...", E],
        [E, E, "..7CCVVVVCC4..", "..8CCccccCC5..", "....CccccC....", "....uuuuuu....", "....mm..mm....", "....bb..bb...."],
    ]),
}

# Afloat the head is as high in every direction (no stand `drop`): the eyes stay over the
# water; the bodies drawn a row lower move up with it.
for _d in ("se", "ne", "n"):
    _drop, _frames = SWIM[_d]
    SWIM[_d] = (0, [f[1:] + [E] for f in _frames])
