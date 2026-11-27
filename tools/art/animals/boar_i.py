"""The boar, ninth drawing: the run (gallop) at size B, from the reference's five run frames, the
south first. The reference gallops: 0 gathered, the ears pricked up, the legs folded under, the body
a pixel low; 1 reaching, the ears out flat, the front legs apart with the hind ones between them;
2 stretched, the head down, the ears laid back to a point on each side, the body a pixel low, the
legs splayed out; 3 gathered with the back arched (the head a row taller, the ears out flat), the
left leg down, the right lifted; 4 landing, the ears up again, the body two pixels low, the right leg
reaching forward over the jaw. The user's rule keeps four frames of the five (the review shows the
choices).
"""
from boar_e import IDLE as IDLE_N  # noqa: F401
from boar_f import EARS_UP, PAL, REF, S0  # noqa: F401

# The face from the eyes to the tusks, as standing.
FACE = S0[8:12]

R0 = EARS_UP[:12] + [
    ".ODDpOODOOOOOO.",
    "..ODDOOOOOpOO..",
    "...hpO...OOh...",
    "....hh...hh....",
]

R1 = S0[:3] + [
    "..OOOOqNqOOOO..",
    ".OLHLMlNlMLHLO.",
    "OLMLMLHqHLMLMLO",
    "..OpMMLLLMMpO..",
] + FACE + [
    ".OMDpOODOOODMO.",
    ".OMDOOOOOODMDO.",
    ".OLO.hO.OOODO..",
    ".OLO..h.q.ODO..",
    "..h.......hh...",
]

R2 = S0[:3] + [
    "....OOqNqOO....",
    "..OODLHqHLDOO..",
    ".OLLLLHqHLLLLO.",
    "OLMDMMLLLMMDMLO",
] + FACE + [
    "OLHMOOODOOOOMMO",
    "OHMOOOpOpOOOMLO",
    "OHO...OOO...OLO",
    ".h...........h.",
]

R3 = S0[:3] + [
    ".....ONnNO.....",
    "..OOOMNNNMOOO..",
    ".OMLDMqNqMDLMO.",
] + S0[5:12] + [
    "..ODOOODOOOOOLO",
    "..OMO..O....OMO",
    "..OMO........h.",
    "...hh..........",
]

R4 = EARS_UP[:10] + [
    ".OMOTLDMDLTOMLO",
    ".ODOttDMDttpLHO",
    "..ODOpODOOhOOHO",
    "..OMh..O....hHO",
    "...h.........h.",
]

RUN5 = {"s": [R0, R1, R2, R3, R4]}
# The choices of four: A leaves out the landing (4), the smoothest loop back to the gathered pose;
# B leaves out the reach (1), the stretch right after the gathering.
RUN_A = {"s": [RUN5["s"][i] for i in (0, 1, 2, 3)]}
RUN_B = {"s": [RUN5["s"][i] for i in (0, 2, 3, 4)]}
