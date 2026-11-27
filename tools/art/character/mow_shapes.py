"""The scythe's shape as ToolArt has it (tools/art/tool_art.gd SHAPES scythe), registered in
work_proto.SHAPES for the mow's review tools."""
import work_proto

SCYTHE = {
    "up": [
        "daaAA..",
        "w..qaAA",
        "w....qA",
        "w.....A",
        "w......",
        "W......",
        "wd.....",
        "w......",
        "W......",
        "w......",
        "w......",
        "d......",
        "g......",
    ],
    "diagonal": [
        "........da...",
        ".......w..aA.",
        "......W....aA",
        ".....w......A",
        "....wd......A",
        "...w.........",
        "..W..........",
        ".d...........",
        "g............",
    ],
    "toward": [
        "g.....",
        "w.....",
        "W.....",
        "w.....",
        "daaAA.",
        "...aAA",
    ],
}
work_proto.SHAPES["scythe"] = SCYTHE
