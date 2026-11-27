T = "shovel"
DIG = {"e": [
    # Lift: the shovel level at the chest, the blade forward.
    {"bob": 1, "top": 12, "r": [10, 13], "a": 2, "slide": 3, "f": False, "tool": T, "rows": [
        "......CVk.....",
        ".....cC4444...",
        ".....UUU55....",
        ".....ttt......",
        "......tTt.....",
        "......BBb....."]},
    # Thrust: the torso a pixel forward, the blade down into the earth.
    {"bob": 1, "top": 12, "r": [10, 13], "a": 3, "slide": 5, "f": False, "tool": T, "rows": [
        ".......CVk....",
        "......cC444...",
        ".....UUU55....",
        ".....ttt......",
        "......tTt.....",
        "......BBb....."]},
    # Push: crouched, the weight on the handle, the blade deep.
    {"bob": 2, "top": 13, "r": [10, 14], "a": 3, "slide": 4, "f": False, "tool": T, "rows": [
        "......CVk.....",
        ".....cC4444...",
        ".....UUU55....",
        ".....ttt......",
        "......BBb....."]},
    # Toss: upright, the blade up and forward.
    {"bob": 1, "top": 12, "r": [10, 12], "a": 1, "slide": 4, "f": False, "tool": T, "rows": [
        "......CVk444..",
        ".....cC445....",
        ".....UUU......",
        ".....ttt......",
        "......tTt.....",
        "......BBb....."]},
]}
