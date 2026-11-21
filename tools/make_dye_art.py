#!/usr/bin/env python3
"""Draws the pictures of the dyes' sources (the dye vat PR): the ground plants madder
(whorls of narrow leaves, small yellow flowers; its root is dug up) and woad (a stalk of
blue-green leaves under a cloud of yellow flowers), and the icons (12x12) of what is
gathered for the dyes: chalk, ochre, ash, nettle leaves, madder root, woad leaves, a murex
snail. The dyes' own icons are bowls drawn by tools/make_icons.gd (IconArt.dye_picture).
Run from the repo:
    python3 tools/make_dye_art.py
Everything is written again.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_plant_art as art  # noqa: E402
from make_curio_art import icon  # noqa: E402

low = art.low

art.PAL.update({
    "1": (70, 120, 50, 255),  # madder leaf
    "2": (110, 158, 72, 255),  # its lit side
    "3": (236, 214, 96, 255),  # madder flower
    "4": (78, 116, 112, 255),  # woad leaf, blue-green
    "5": (118, 156, 146, 255),  # its lit side
    "6": (246, 222, 70, 255),  # woad flower
    "7": (204, 176, 44, 255),  # its shade
    "8": (90, 112, 70, 255),  # woad stalk
})

# Madder: a low sprawl of square stems ringed with whorls of narrow leaves, a few small
# yellow flowers at the tips.
MADDER = [
    low("...3....", "..131.3.", "...1..1.", ".2.1.212", "2121..1.", "..21.1..", "1..1212.", ".2121...",
        "...1.1..", "..2121..", "...11..."),
    low(".....3..", ".3..131.", ".1...1..", "212.21..", ".1.2121.", ".1..1..2", "2121.21.", "..1.1...",
        "..2121..", "...11..."),
]

# Woad: a tall stalk, broad blue-green leaves clasping it below, a loose cloud of tiny
# yellow flowers on top.
WOAD = [
    low("..6.6...", ".67676..", "6.676.6.", ".7.8.7..", "...8....", "...8....", "..58....", ".548....",
        "..48.5..", "...845..", "..58.4..", ".5484...", ".44845..", "..4844..", "..4444.."),
    low("...6.6..", "..67676.", ".6.676.6", "..7.8.7.", "....8...", "....8...", "...58...", "..548...",
        "...48.5.", "....845.", "...58.4.", "..5484..", "..44845.", "...4844.", "...4444."),
]


def plants():
    art.sprite("madder", MADDER)
    art.sprite("woad", WOAD)


def icons():
    pal = {
        "w": (240, 236, 226, 255), "W": (252, 250, 244, 255), "v": (200, 194, 182, 255),  # chalk
        "o": (204, 146, 58, 255), "O": (232, 182, 92, 255), "q": (150, 98, 40, 255),  # ochre
        "a": (156, 154, 150, 255), "A": (196, 194, 190, 255), "z": (110, 108, 106, 255), "k": (50, 46, 44, 255),  # ash
        "n": (62, 104, 42, 255), "N": (108, 150, 70, 255), "m": (40, 74, 30, 255),  # nettle
        "r": (170, 62, 44, 255), "R": (206, 98, 70, 255), "s": (112, 40, 30, 255),  # madder root
        "b": (78, 116, 112, 255), "B": (118, 156, 146, 255), "c": (52, 82, 80, 255),  # woad
        "p": (150, 74, 128, 255), "P": (208, 150, 186, 255), "u": (234, 220, 200, 255), "U": (200, 184, 160, 255),  # murex
    }
    icon("chalk", "materials", "finds", [
        "............", "............", "............", ".....WW.....", "...WWwwW....", "..Wwwwwwv...",
        "..wwwwwwvv..", ".Wwwwwvwvv..", ".wwwwvvvv...", "..vvvvvv....", "............", "............"], pal)
    icon("ochre", "materials", "finds", [
        "............", "............", "............", "....OO......", "...OOoOO....", "..OoooooO...",
        "..oooooqoo..", ".Oooooqqoq..", ".ooooqqqq...", "..qqqqqq....", "............", "............"], pal)
    icon("ash", "plants", "dyes", [
        "............", "............", "............", "............", ".....AA.....", "....AAaa....",
        "...AaakaA...", "..AaaaaazA..", ".Aaaakaaazz.", ".zzzzzzzzz..", "............", "............"], pal)
    icon("nettle_leaves", "plants", "nettle", [
        "............", "......N.....", ".....NnN....", "....NnnnN...", "...NnnmnnN..", "....nnmnn...",
        "..N.NnmnN...", ".NnN.nmn....", "NnmnN.m.....", ".nmn..m.....", "..m...m.....", "............"], pal)
    icon("madder_root", "plants", "madder", [
        "............", "....1.2.....", ".....12.....", ".....rR.....", "....rRrr....", "...rRr.rr...",
        "..rr.r..r...", ".rs..rr..r..", ".s...r.s..s.", "....s..s....", "...s....s...", "............"],
         dict(pal, **{"1": art.PAL["1"], "2": art.PAL["2"]}))
    icon("woad_leaves", "plants", "woad", [
        "............", ".....BB.....", "....BbbB....", "...Bbbcbb...", "...bbbcbb...", "..BbbbcbbB..",
        "..bbbcbbb...", "...bbcbbb...", "...bbcbb....", "....bcb.....", ".....c......", "............"], pal)
    icon("murex", "materials", "finds", [
        "............", "......u.....", ".....uUu.u..", "..u.uPpPuU..", "...uPppppU..", "..uUPpPppUu.",
        "...UPppPpU..", "..u.UPpPU...", "....UUpUu...", ".....Up.....", "......p.....", "............"], pal)


def main():
    plants()
    icons()


if __name__ == "__main__":
    main()
