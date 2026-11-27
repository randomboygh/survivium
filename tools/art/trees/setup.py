"""Readies ref/ for the trees' program: the last frame of each of the user's three reference GIFs at its own
pixels (256 x 256, NEAREST: c_n.png for 122-deciduous, l_n.png for 123-leaf-styles, k_n.png for 124-conifer) and the
pine's bark from the game (ref/bark/pine_bark.png). Run once after a checkout; git ignores what it writes.

    python3 tools/art/trees/setup.py
"""
import os
import shutil

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(HERE, "ref")
REPO = os.path.join(HERE, "..", "..", "..")

for gif, out in [("122-deciduous", "c_n"), ("123-leaf-styles", "l_n"), ("124-conifer", "k_n")]:
    im = Image.open(os.path.join(REF, gif + ".gif"))
    im.seek(im.n_frames - 1)
    im.convert("RGB").resize((256, 256), Image.NEAREST).save(os.path.join(REF, out + ".png"))
shutil.copy(os.path.join(REPO, "content", "plants", "pine", "textures", "pine_bark.png"), os.path.join(REF, "bark"))
print("ref ready: " + REF)
