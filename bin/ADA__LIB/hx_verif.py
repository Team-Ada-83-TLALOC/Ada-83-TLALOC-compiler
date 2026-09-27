#!/usr/bin/env python3
"""Verification croisee d'une image HX (codi_HX) contre l'image TX (codi_TX) du meme programme.

   hx_verif.py SPEC PROG.tx PROG.hx [codi_TX.finc] [-l]

codi_TX.finc fournit les codes TX ; par defaut ../codis/codi_TX.finc a cote de ce script.

La table de decodage HX est construite a partir de la table des opcodes de
LLIR_hardware_support (colonnes binaire, nom, [complement]) : ce script ne partage
aucun code avec codi_HX. Il verifie :
  - l'en-tete HX et la table des instructions ;
  - que chaque instruction decodee a la longueur donnee par son opcode et ne deborde pas
    sur l'instruction suivante de la table ;
  - que toute cible de branche ou de CALL est un debut d'instruction ;
  - que la suite des instructions HX est exactement celle attendue a partir de l'image TX
    (memes operandes, cibles correspondantes), replis et SYS_EXIT compris.
-l : liste desassemblee de l'image HX.
"""
import re, struct, sys

BASE = 0x400000
FIN_TX = BASE
LONG_COMPL = {'B16': 2, 'B24': 3, 'C24': 3, 'C32': 4, 'D8': 1, 'D16': 2, 'D24': 3, 'D32': 4,
              'D64': 8, 'D8_8': 2, 'BR8': 1, 'BR16': 2, 'BR24': 3, 'BR32': 4}

def lire_spec(chemin):
    table = {}
    for ligne in open(chemin, encoding='utf-8', errors='replace'):
        ligne = ligne.rstrip('\r\n')
        m = re.match(r'^(\d+)\t([ABCD])\t(b[01_i]+)\tx\t(.*)$', ligne)
        if not m:
            continue
        fam, binaire, reste = m.group(2), m.group(3), m.group(4).split(';')[0]
        mots = reste.split()
        nom = mots[0]
        compl = None
        for mot in mots[1:]:
            if mot.startswith('['):
                compl = mot.strip('[]')
        bits = binaire[1:].replace('_', '')
        if 'i' in bits:                                   # LI imm4
            for i in range(16):
                table[0xD0 + i] = ('LI4', fam, None)
            continue
        table[int(bits, 2)] = (nom, fam, compl)
    return table

def signe(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v

class Image:
    def __init__(self, chemin, signature):
        self.o = open(chemin, 'rb').read()
        assert self.o[:8] == signature, 'signature %r attendue' % signature
        (self.version, base, self.entree, self.taille, rec, self.cev,
         tab, nb) = struct.unpack_from('<8Q', self.o, 8)
        assert base == BASE
        brut = [struct.unpack_from('<I', self.o, tab - BASE + 4 * k)[0] for k in range(nb)]
        if signature == b'TLALOCHX':
            #  bit 31 SUITE, bit 30 VIDE ; les entrees VIDE ne designent pas d'instruction
            self.drapeaux = [(e >> 30) & 3 for e in brut]
            self.adr = [BASE + (e & 0x3FFFFFFF) for e in brut if not (e >> 30) & 1]
            self.suite = [(e >> 31) & 1 for e in brut if not (e >> 30) & 1]
        else:
            self.adr = [BASE + e for e in brut]
    def u(self, a, n):
        return int.from_bytes(self.o[a - BASE:a - BASE + n], 'big')

# ------------------------------------------------------------------ decodage HX
NON_MINIMALES = []

def decoder_hx(img, spec):
    instrs = []
    for k, a in enumerate(img.adr):
        op = img.o[a - BASE]
        if op not in spec:
            raise SystemExit('%06X : opcode reserve %02X' % (a, op))
        nom, fam, compl = spec[op]
        n = LONG_COMPL.get(compl, 0)
        L = 1 + n
        if k + 1 < len(img.adr) and a + L > img.adr[k + 1]:
            raise SystemExit('%06X : %s deborde sur l\'instruction suivante' % (a, nom))
        c = img.u(a + 1, n) if n else 0
        suiv = a + L
        if nom == 'LI4':
            t = ('LI', op & 15)
        elif nom == 'LI':
            t = ('LI', signe(c, 8 * n))
        elif fam in 'BC' and nom not in ('LINK', 'EXC_MACH') and not nom.startswith('CHK'):
            if compl is None:
                lvl, disp, ofs = -1, 0, 0
            elif compl == 'B16':
                lvl, disp, ofs = c >> 12, signe(c & 0xFFF, 12), 0
            elif compl == 'B24':
                lvl, disp, ofs = c >> 20, signe(c & 0xFFFFF, 20), 0
            elif compl == 'C24':
                lvl, ofs, disp = c >> 20, (c >> 16) & 15, signe(c & 0xFFFF, 16)
            else:
                lvl, ofs, disp = c >> 28, (c >> 20) & 255, signe(c & 0xFFFFF, 20)
            if lvl == 15:
                lvl = -1
            t = (nom, lvl, disp) if fam == 'B' else (nom, lvl, disp, ofs)
        elif nom in ('LINK', 'EXC_MACH'):
            if compl == 'B16':
                lvl, d = c >> 12, c & 0xFFF
            else:
                lvl, d = c >> 20, c & 0xFFFFF
            if nom == 'EXC_MACH':
                d = signe(d, 12 if compl == 'B16' else 20)
            t = (nom, lvl, d)
        elif nom.startswith('CHK'):
            if fam == 'B':
                t = (nom, c >> 20, signe(c & 0xFFFFF, 20))
            else:
                t = (nom, c >> 28, signe(c & 0xFFFFF, 20), (c >> 20) & 255)
        elif nom in ('BRA', 'BT', 'BF'):
            t = (nom, suiv + signe(c, 8 * n))
        elif nom == 'CALL':
            t = (nom, suiv + signe(c, 24))
        elif nom in ('UBFXI', 'SBFXI', 'BFII'):
            t = (nom, c >> 8, c & 255)
        elif nom in ('RTD', 'TRAP', 'UNLINK', 'UNLINKR', 'EXC_RAISE'):
            t = (nom, c)
        elif nom.startswith('LEXCMP') or nom.startswith('ULEXCMP'):
            t = ('LEXCMP', 1 << (op & 3), 0 if (op & 4) else 1)
        else:
            t = (nom,)
        m = longueur_minimale(t[0], fam, t)
        if m is not None and m != L:
            NON_MINIMALES.append('%06X : %s code sur %d octets au lieu de %d' % (a, t, L, m))
        if t[0] in ('BRA', 'BT', 'BF') and n > 1 and tient(signe(c, 8 * n), 8 * (n - 1)):
            NON_MINIMALES.append('%06X : %s en BR%d, tiendrait en BR%d' % (a, t, 8 * n, 8 * (n - 1)))
        instrs.append((a, L, t))
    return instrs

# ------------------------------------------------------------------ longueur minimale
def tient(v, bits):
    return -(1 << (bits - 1)) <= v < (1 << (bits - 1))

def longueur_minimale(nom, fam, t):
    """longueur du plus court encodage de l'instruction t selon la specification"""
    if nom == 'LI':
        v = t[1]
        return 1 if 0 <= v <= 15 else 2 if tient(v, 8) else 3 if tient(v, 16) else 5 if tient(v, 32) else 9
    if nom == 'LINK':
        return 3 if t[2] < 4096 else 4
    if nom == 'EXC_MACH':
        return 3 if tient(t[2], 12) else 4
    if nom.startswith('CHK'):
        return 4 if fam == 'B' else 5
    if nom in ('BRA', 'BT', 'BF'):
        return None                               # verifie a part, sur le deplacement
    if fam == 'B':
        lvl, disp = t[1], t[2]
        return 1 if (lvl == -1 and disp == 0) else 3 if tient(disp, 12) else 4
    if fam == 'C':
        lvl, disp, ofs = t[1], t[2], t[3]
        if lvl == -1 and disp == 0 and ofs == 0:
            return 1
        return 4 if (ofs <= 15 and tient(disp, 16)) else 5
    return None

# ------------------------------------------------------------------ attendu depuis TX
def codes_tx(codi):
    codes = {}
    for m in re.finditer(r'^TX_(\w+)\s*=\s*(\d+)', open(codi).read(), re.M):
        if not m.group(1).startswith('SYS_'):
            codes[int(m.group(2))] = m.group(1)
    return codes

B_OPS = {'LVA', 'LB', 'LW', 'LD', 'LQ', 'LA', 'ULB', 'ULW', 'ULD', 'SB', 'SW', 'SD', 'SQ', 'SA'}
C_OPS = {'LIVA', 'LIB', 'LIW', 'LID', 'LIQ', 'LIA', 'ULIB', 'ULIW', 'ULID', 'SIB', 'SIW', 'SID', 'SIQ', 'SIA'}
ALIAS = {'LA': 'LQ', 'SA': 'SQ', 'LIA': 'LIQ', 'SIA': 'SIQ'}
C_VERS_B = {'LIVA': 'LVA', 'LIB': 'LB', 'LIW': 'LW', 'LID': 'LD', 'LIQ': 'LQ', 'ULIB': 'ULB',
            'ULIW': 'ULW', 'ULID': 'ULD', 'SIB': 'SB', 'SIW': 'SW', 'SID': 'SD', 'SIQ': 'SQ'}

CHK_CHARGE = {'CHKIB': ('LIB', 1), 'CHKIW': ('LIW', 2), 'CHKID': ('LID', 4), 'CHKIQ': ('LIQ', 8),
              'CHKUIB': ('ULIB', 1), 'CHKUIW': ('ULIW', 2), 'CHKUID': ('ULID', 4)}
CEV_TX = 0

def attendu(nom, lvl, ofs, val, cible):
    """suite de tuples HX attendue pour une instruction TX ; cible() traduit une adresse TX"""
    nom = ALIAS.get(nom, nom)
    v64 = signe(val, 64)
    if nom in ('LI', 'LIF', 'LCA', 'LSPA'):
        if nom in ('LCA', 'LSPA'):                       # seules adresses de l'image
            return [('LI', ('ADR', val))]
        return [('LI', v64)]
    if nom in B_OPS:
        if nom == 'LVA' and lvl == -1 and v64 == 0:
            return []
        return [(nom, lvl, v64)]
    if nom in C_OPS:
        if lvl == -1 and v64 == 0 and ofs == 0:
            return [('LQ', -1, 0)] if nom == 'LIVA' else [(nom, -1, 0, 0)]
        if 0 <= ofs <= 255:
            return [(nom, lvl, v64, ofs)]
        liva = [('LQ', -1, 0)] if (lvl == -1 and v64 == 0) else [('LIVA', lvl, v64, 0)]
        b = (C_VERS_B[nom], -1, ofs)
        if not nom.startswith('S'):
            return liva + [b]
        if lvl != -1:
            return liva + [('OVER',), b, ('DROP',)]
        return [('OVER',)] + liva + [('OVER',), b, ('DROP',), ('DROP',)]
    if nom in ('BRA', 'BT', 'BF', 'CALL'):
        return [(nom, cible(val))]
    if nom in ('LINK', 'EXC_MACH'):
        return [(nom, lvl, v64)]
    if nom in ('UNLINK', 'UNLINKR'):
        return [(nom, lvl)]
    if nom in ('RTD', 'EXC_RAISE'):
        return [(nom, val)]
    if nom == 'TRAP':
        return [('LI', ofs), ('TRAP', 0)] if val == 0 else [('TRAP', val)]
    if nom == 'LEXCMP':
        return [('LEXCMP', ofs, 1 if (lvl == 1 or ofs == 8) else 0)]
    if nom.startswith('CHKI') or nom.startswith('CHKUI'):
        if 0 <= ofs <= 255 and tient(v64, 20):
            return [(nom, lvl, v64, ofs)]
        charge, taille = CHK_CHARGE[nom]                 # sequence de remplacement
        ce = ('BT', cible(CEV_TX))
        return ([('DUP',)] + attendu(charge, lvl, ofs, val, cible) + [('CLT',), ce, ('DUP',)]
                + attendu(charge, lvl, ofs + taille, val, cible) + [('CGT',), ce])
    if nom.startswith('CHK'):
        return [(nom, lvl, v64)]
    if nom in ('UBFXI', 'SBFXI', 'BFII'):
        return [(nom, val, ofs)]
    return [(nom,)]

def main():
    spec_ch, tx_ch, hx_ch = sys.argv[1:4]
    liste = '-l' in sys.argv
    spec = lire_spec(spec_ch)
    nb_ops = len({v[0] for v in spec.values()})
    global FIN_TX, CEV_TX
    tx = Image(tx_ch, b'TLALOCTX')
    FIN_TX = BASE + len(tx.o)
    CEV_TX = tx.cev
    hx = Image(hx_ch, b'TLALOCHX')
    assert hx.version == 1 and hx.entree == BASE + 0x78 and hx.adr[0] == hx.entree
    import os
    defaut = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'codis', 'codi_TX.finc')
    codes = codes_tx(sys.argv[4] if len(sys.argv) > 4 and not sys.argv[4].startswith('-')
                     else defaut)
    ins = decoder_hx(hx, spec)
    debuts = {a for a, _, _ in ins}

    # lecture TX
    rec = []
    for a in tx.adr:
        op, lvl = tx.o[a - BASE], signe(tx.o[a - BASE + 1], 8)
        ofs = signe(struct.unpack_from('<I', tx.o, a - BASE + 4)[0], 32)
        val = struct.unpack_from('<Q', tx.o, a - BASE + 8)[0]
        rec.append((a, codes[op], lvl, ofs, val))
    # premiere passe : taille de chaque groupe, correspondance adresse TX -> adresse HX
    nul = lambda v: 0
    groupes, k = [], 0
    for a, nom, lvl, ofs, val in rec:
        n = len(attendu(nom, lvl, ofs, val, nul))
        groupes.append(k)
        k += n
    if k != len(ins):
        raise SystemExit('nombre d\'instructions : %d attendues, %d dans l\'image HX' % (k, len(ins)))
    #  drapeaux de la table : SUITE sur toute instruction d'un groupe sauf la premiere,
    #  une entree VIDE par instruction LLIR sans instruction HX, juste avant la suivante
    attendus = []
    for a, nom, lvl, ofs, val in rec:
        n = len(attendu(nom, lvl, ofs, val, nul))
        attendus += [2] if n == 0 else [0] + [1] * (n - 1)      # 2 : VIDE, 1 : SUITE
    obtenus = [2 if d & 1 else (d >> 1) for d in hx.drapeaux]
    if obtenus != attendus:
        i = next(i for i in range(min(len(obtenus), len(attendus))) if obtenus[i] != attendus[i]) \
            if any(x != y for x, y in zip(obtenus, attendus)) else min(len(obtenus), len(attendus))
        raise SystemExit('drapeaux de la table : premier desaccord a l\'entree %d (attendu %s, obtenu %s)'
                         % (i, attendus[i:i+3], obtenus[i:i+3]))
    #  une entree VIDE porte l'adresse de l'instruction suivante
    brut_adr = [(e & 0x3FFFFFFF) for e in [struct.unpack_from('<I', hx.o, struct.unpack_from('<Q', hx.o, 56)[0]
                - BASE + 4 * j)[0] for j in range(len(hx.drapeaux))]]
    for j, d in enumerate(hx.drapeaux):
        if d & 1 and j + 1 < len(hx.drapeaux) and brut_adr[j] != brut_adr[j + 1]:
            raise SystemExit('entree VIDE %d : adresse %X differente de la suivante' % (j, brut_adr[j]))
    vers_hx = {}
    for (a, *_), g in zip(rec, groupes):
        vers_hx[a] = ins[g][0] if g < len(ins) else None
    if tx.cev and vers_hx.get(tx.cev) != hx.cev:
        raise SystemExit('CEV : TX %X -> %X attendu, en-tete HX %X' % (tx.cev, vers_hx.get(tx.cev, 0), hx.cev))
    def cible(v):
        if v not in vers_hx or vers_hx[v] is None:
            raise SystemExit('cible TX %X hors table' % v)
        return vers_hx[v]
    # seconde passe : comparaison
    ecarts = len(NON_MINIMALES)
    for m in NON_MINIMALES[:10]:
        print('NON MINIMALE', m)
    if NON_MINIMALES:
        print('%d instructions non minimales' % len(NON_MINIMALES))
    donnees = {}                                  # adresse de donnee TX -> adresse HX
    debuts_tx = set(tx.adr)
    for (a, nom, lvl, ofs, val), g in zip(rec, groupes):
        att = attendu(nom, lvl, ofs, val, cible)
        obt = [t for _, _, t in ins[g:g + len(att)]]
        if len(att) == 1 and att[0][0] == 'LI' and isinstance(att[0][1], tuple) and \
           len(obt) == 1 and obt[0][0] == 'LI':
            v_tx, v_hx = att[0][1][1], obt[0][1]
            if v_tx in debuts_tx:
                att = [('LI', vers_hx[v_tx])]     # adresse d'instruction (LSPA, etiquette)
            else:
                if donnees.setdefault(v_tx, v_hx) != v_hx:
                    ecarts += 1
                    print('ECART TX %06X : donnee %X vue en %X et %X' % (a, v_tx, donnees[v_tx], v_hx))
                att = obt
        if att != obt:
            ecarts += 1
            if ecarts <= 20:
                print('ECART TX %06X %-10s attendu %s  obtenu %s' % (a, nom, att, obt))
    # adresses de donnees : correspondance croissante, ecarts conserves (a l'alignement pres)
    paires = sorted(donnees.items())
    for (t1, h1), (t2, h2) in zip(paires, paires[1:]):
        code_entre = any(t1 < x < t2 for x in tx.adr)
        if h2 <= h1 or (not code_entre and abs((h2 - h1) - (t2 - t1)) >= 8):
            ecarts += 1
            print('ECART donnees : TX %X -> %X et TX %X -> %X' % (t1, h1, t2, h2))
        if not (BASE <= h2 < BASE + len(hx.o)) or h2 in debuts:
            ecarts += 1
            print('ECART donnees : HX %X hors des donnees' % h2)
    br = [0] * 5
    for a, L, t in ins:
        if t[0] in ('BRA', 'BT', 'BF'):
            br[L - 1] += 1
        if t[0] in ('BRA', 'BT', 'BF', 'CALL') and t[1] not in debuts:
            ecarts += 1
            print('ECART %06X : cible %X hors debut d\'instruction' % (a, t[1]))
    if liste:
        for a, L, t in ins:
            print('%06X  %-18s %s' % (a, hx.o[a - BASE:a - BASE + L].hex(' '), ' '.join(map(str, t))))
    code = sum(L for _, L, _ in ins)
    print('branches BR8 / BR16 / BR24 / BR32 : %d / %d / %d / %d' % tuple(br[1:]))
    exp = len(ins) - len(rec)
    print('table : %d SUITE, %d VIDE' % (sum(hx.suite), sum(1 for d in hx.drapeaux if d & 1)))
    print('%s : %d opcodes dans la spec ; %d instructions TX -> %d HX (%+d) ; code %d octets '
          '(%.2f o/i) ; %d adresses de donnees ; image %d octets ; %s' % (hx_ch, nb_ops, len(rec),
          len(ins), exp, code, code / len(ins), len(donnees), len(hx.o), 'CONFORME' if ecarts == 0 else '%d ECARTS' % ecarts))
    sys.exit(1 if ecarts else 0)

main()
