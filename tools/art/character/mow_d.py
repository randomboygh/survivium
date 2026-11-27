"""The mow, draft 4 (the user's edit of 2026-11-20 19:06 MSK on mow-all-1.gif: «Во всех видах выносить
косу за персонажа на 2 пикселя меньше. То есть персонаж должен держать косу не за кончик ручки, а
за середину. В виде спереди и сзади тоже»). mow_b with the scythe slid two pixels through the hands
toward the body in every frame: the hands are where they were, the blade is two pixels nearer, and
the snath's end comes out past the hands on the other side. From the side it shows there: over the
waistband in front of the fists (frames 1-2), on the hip under the arm (3-4). From the front it is
behind the forearm that crosses the chest, from behind behind the body. The trails are two pixels
shorter at each end with the blade.

1 the scythe at the mower's right side, its far end up, the blade hanging to the ground;
2 its far end a pixel up, the torso toward it; 3 crouched, the scythe at the other side, the white
trail along the ground in front of the feet; 4 standing, the scythe where it stopped."""
from mow_canvas import F, moved, smear
from mow_a import S, S_LOW, E, E_LOW, SE, SE_LOW, NE, NE_LOW, N, N_LOW

E30 = "." * 30

# The scythe at the right of the picture, from the front and turned: frames 3 and 4.
S_RIGHT = [E30,
           "........................wd....",
           "......................ww.qa...",
           "...........ww$$%$$w&&w....aA..",
           "..........................aA..",
           "...........................A..",
           "..........................A...",
           E30]
SE_RIGHT = ["........................wd....",
            "......................ww.qa...",
            "....................ww....aA..",
            "............ww$%$$w&7.....aA..",
            "...........................A..",
            "..........................A...",
            E30]
E_FRONT = [".....................wd.......",
           "....................w.qa......",
           "...............44$$w...aA.....",
           "...............ww......aA.....",
           "........................A.....",
           ".......................A......",
           E30]
# Seen from behind: at the right (frames 1, 2), then at the left with the left hand on it.
BACK_RIGHT = ["........................wd....",
              "......................ww.qa...",
              "....................ww....aA..",
              "..................$$......aA..",
              "................ww.........A..",
              "..........................A...",
              E30]
BACK_UP = ["........................wd....",
           ".......................w.qa...",
           "......................w...aA..",
           ".....................w....aA..",
           "...................$$......A..",
           "..................w.......A...",
           E30, E30]
NE_LEFT = [".....dw.......................",
           "....aq.ww.....................",
           "...Aa....ww...................",
           "...Aa......&*.................",
           "...A........ww................",
           "....A.........................",
           E30]
N_LEFT = ["....dw........................",
          "...aq.ww......................",
          "..Aa....w.....................",
          "..Aa.....&*...................",
          "..A........ww.................",
          "...A..........................",
          E30]
FRONT_TRAIL = ["..--..........................",
               "....-++................oo.....",
               ".......+++o........oooo.......",
               "...........oooooooo..........."]

MOW = {
    "s": [
        F(0, 10, [E30,
                  "....dw........................",
                  "...aq.ww......................",
                  "..Aa....w$$w&&***ww...........",
                  "..Aa..........................",
                  "..A...........................",
                  "...A..........................",
                  E30], grip=(1, 13), a=10, base=S),
        F(0, 9, [E30,
                 "....dw........................",
                 "...aq.w.......................",
                 "..Aa...w......................",
                 "..Aa....$$w&&***ww............",
                 "..A...........................",
                 "...A..........................",
                 E30, E30], grip=(0, 13), a=10, base=moved(S, [0, 1, 2], -1)),
        F(1, 10, S_RIGHT, grip=(8, 13), a=9, base=moved(S_LOW, [0, 1], 1),
          smear=smear(10, [E30, E30, E30, E30] + FRONT_TRAIL)),
        F(0, 10, S_RIGHT, grip=(8, 13), a=9, base=S),
    ],
    "se": [
        F(1, 11, ["....dw........................",
                  "...aq.ww......................",
                  "..Aa....ww....................",
                  "..Aa......$$w&&**ww...........",
                  "..A...........................",
                  "...A..........................",
                  E30], grip=(2, 14), a=10, base=SE),
        F(1, 10, ["....dw........................",
                  "...aq.w.......................",
                  "..Aa...w......................",
                  "..Aa....w.....................",
                  "..A......$$w&&**ww............",
                  "...A..........................",
                  E30, E30], grip=(1, 14), a=10, base=moved(SE, [0, 1, 2], -1)),
        F(2, 11, SE_RIGHT, grip=(8, 14), a=9, base=moved(SE_LOW, [0, 1], 1),
          smear=smear(11, [E30, E30, E30] + FRONT_TRAIL)),
        F(1, 11, SE_RIGHT, grip=(8, 14), a=9, base=SE),
    ],
    "e": [
        F(1, 11, ["......dw......................",
                  ".....aq.ww....................",
                  "....Aa....ww..4...............",
                  "....Aa......$$ww..............",
                  "....A.........................",
                  ".....A........................",
                  E30], grip=(4, 14), a=10, base=E),
        F(1, 10, [".....dw.......................",
                  "....aq.w......................",
                  "...Aa...w.....................",
                  "...Aa....ww..4................",
                  "...A.......$$ww...............",
                  "....A.........................",
                  E30, E30], grip=(3, 14), a=10, base=moved(E, [0, 1], -1)),
        F(2, 11, E_FRONT, grip=(9, 13), a=9, base=E_LOW, smear=smear(11, [
                  E30, E30, E30,
                  "...--.........................",
                  ".....-++......................",
                  "........+++oo.....oooo........",
                  ".............ooooo............"])),
        F(1, 11, E_FRONT, grip=(9, 13), a=9, base=E),
    ],
    "ne": [
        F(1, 11, BACK_RIGHT, grip=(10, 14), a=9, base=NE),
        F(1, 10, BACK_UP, grip=(11, 14), a=9, base=moved(NE, [0, 1, 2], 1)),
        F(2, 11, NE_LEFT, grip=(5, 14), a=10, f=False, base=NE_LOW, smear=smear(11, [
                  E30, E30, E30, E30,
                  ".........oo........++++.......",
                  "......ooo..............---....",
                  E30])),
        F(1, 11, NE_LEFT, grip=(5, 14), a=10, f=False, base=NE),
    ],
    "n": [
        F(1, 11, BACK_RIGHT, grip=(10, 14), a=9, base=N),
        F(1, 10, BACK_UP, grip=(11, 14), a=9, base=moved(N, [0, 1, 2], 1)),
        F(2, 11, N_LEFT, grip=(3, 14), a=10, f=False, base=moved(N_LOW, [0, 1], -1), smear=smear(11, [
                  E30, E30, E30, E30,
                  "........o..........++++.......",
                  ".....ooo...............---....",
                  E30])),
        F(1, 11, N_LEFT, grip=(3, 14), a=10, f=False, base=N),
    ],
}
