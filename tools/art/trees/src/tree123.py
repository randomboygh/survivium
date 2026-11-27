# The chosen tree (round 17 limbs + round 16 crowns, render17.Tree, small=False) with the leaf modules of
# one of four styles: '122' (today's, module5) or reference 123's 'dots', 'blades', 'round' (module123).
# The 123 modules are smaller than 122's (rms radius x0.83 / 0.89 / 0.91), so by default they are set
# that much closer on the rings (step and hstep 15 x ratio): the crown keeps the approved fullness.
import numpy as np
import render17 as T, module123 as MM

RATIO = {'dots': 0.83, 'blades': 0.89, 'round': 0.91}

class Tree(T.Tree):
    def __init__(self, sun, leaves='122', dense=True, **kw):
        self.leaves = leaves
        if leaves in RATIO and dense:
            kw.setdefault('step', 15 * RATIO[leaves]); kw.setdefault('hstep', 15 * RATIO[leaves])
        super().__init__(sun, **kw)
        if leaves in RATIO:
            mods = MM.modules(leaves)
            self.mods = [(p, n, mods[(i * 5 + self.seed) % len(mods)]) for i, (p, n, _) in enumerate(self.mods)]
            self._tones = {}

    def tones(self, mod, shade=False):
        if 'style' not in mod: return super().tones(mod, shade)
        key = (id(mod), shade)
        if key not in self._tones:
            t = MM.tones(mod, self.light2).astype(float)
            if shade:
                flat = MM.tones(mod, self.light2, flat=True)
                lt = t - flat
                if shade == 'flat': t = np.where(t > -9, flat + np.minimum(lt, 0), t)
                elif shade == 'lift': t = np.where(t > -9, flat + np.maximum(lt, 0), t)
                elif shade in ('half', 'quarter'):
                    keep = 0.5 if shade == 'half' else 0.75
                    t = np.where(t > -9, flat + np.where(lt < 0, lt * keep, lt), t)
            self._tones[key] = t
        return self._tones[key]
