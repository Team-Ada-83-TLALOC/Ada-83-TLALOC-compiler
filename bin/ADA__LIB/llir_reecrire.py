#!/usr/bin/env python3
"""Reecritures LLIR que le front end TLALOC devra produire lui-meme.

 1. Controle d'intervalle (8 lignes) -> CHKx
      DUP / Lx a / CLT / BT STANDARD.ce_raise_ / DUP / Lx b / CGT / BT STANDARD.ce_raise_
      -> CHKx a            (a designe ...FST ou FST_n, b la borne LST correspondante)
 2. Champ aligne lu juste apres une charge -> charge etroite
      Lx op / LI lsb / LI w / UBFX   -> ULB|ULW|ULD op+lsb/8   (SBFX : LB|LW|LD)
      si lsb multiple de 8, w = 8, 16 ou 32, lsb + w <= taille chargee
 3. Champ a position et largeur constantes -> forme immediate
      LI lsb / LI w / UBFX|SBFX|BFI  -> UBFXI|SBFXI|BFII lsb, w
 4. Peephole : adresse produite par LVA/LA et consommee aussitot au sommet (lvl = -1)
      LVA l, d / Bx , e      -> Bx l, d+e          (Bx : LVA, charges de la famille B)
      LVA l, d / Cx , e, o   -> Cx l, d+e, o       (Cx : LIVA, charges de la famille C)
      LA  l, d / Bx , e      -> Cx l, d, e         (LQ comme LA ; LB -> LIB, LVA -> LIVA...)
      LIVA l, d, o / Bx , e  -> Cx l, d, o+e
      LA  l, d / Cx , e, o      reste : double indirection
   Les rangements ne sont pas concernes : leur adresse n'est pas au sommet.
 5. Adresse nulle : LVA sans operande (lvl = -1, disp = 0) laisse le sommet inchange
      LVA  /  LVA -1  /  LVA -1, 0   -> supprimee
    Les codis la suppriment deja a l'assemblage, y compris quand le deplacement est un
    symbole valant 0 (premier composant d'un enregistrement) ; cette regle textuelle ne
    fait qu'alleger le .FINC.
Apres chaque reecriture, la ligne precedente est reexaminee : les regles s'enchainent
(LA l,d / LD / LI 24 / LI 8 / UBFX  ->  LID l, d, 0 / LI 24 / LI 8 / UBFX  ->  ULIB l, d, 0+3).
Seules des lignes consecutives sont reecrites ; une etiquette, un commentaire ou
une ligne vide entre deux instructions empeche la reecriture."""
import re, sys

CHK = {'LB':'CHKB','LW':'CHKW','LD':'CHKD','LQ':'CHKQ','ULB':'CHKUB','ULW':'CHKUW','ULD':'CHKUD',
       'LIB':'CHKIB','LIW':'CHKIW','LID':'CHKID','LIQ':'CHKIQ','ULIB':'CHKUIB','ULIW':'CHKUIW','ULID':'CHKUID'}
CHARGE_B = {'LB':1,'LW':2,'LD':4,'LQ':8,'LA':8,'ULB':1,'ULW':2,'ULD':4}
CHARGE_C = {'LIB':1,'LIW':2,'LID':4,'LIQ':8,'LIA':8,'ULIB':1,'ULIW':2,'ULID':4}
ETROITE = {('UBFX','B'):{8:'ULB',16:'ULW',32:'ULD'}, ('UBFX','C'):{8:'ULIB',16:'ULIW',32:'ULID'},
           ('SBFX','B'):{8:'LB', 16:'LW', 32:'LD'},  ('SBFX','C'):{8:'LIB', 16:'LIW', 32:'LID'}}
IMMEDIAT = {'UBFX':'UBFXI', 'SBFX':'SBFXI', 'BFI':'BFII'}
ACCES_B = ('LVA', 'LB', 'LW', 'LD', 'LQ', 'LA', 'ULB', 'ULW', 'ULD')
ACCES_C = ('LIVA', 'LIB', 'LIW', 'LID', 'LIQ', 'LIA', 'ULIB', 'ULIW', 'ULID')
B_VERS_C = dict(zip(ACCES_B, ACCES_C))

def instr(l):
    if ';' in l:                                   # prudence : pas de reecriture si commentaire
        return (None, None)
    m = re.match(r'\s+([A-Z_][A-Z0-9_]*)\s*(.*?)\s*$', l)
    return (m.group(1), m.group(2)) if m else (None, None)

def entier(t):
    try:
        return int(t, 0)
    except (TypeError, ValueError):
        return None

def operandes(texte, n):
    ops = [o.strip() for o in texte.split(',')] if texte.strip() else []
    return ops + [''] * (n - len(ops))

def decaler(expr, k):
    if k == 0:
        return expr
    return '%s+%d' % (expr, k) if expr else str(k)

def somme(d, e):
    """expression d + e ; un operande vide vaut 0"""
    if e in ('', '0'):
        return d
    if d in ('', '0'):
        return e
    if re.fullmatch(r'-?[\w.]+', e):
        return d + e if e.startswith('-') else '%s+%s' % (d, e)
    return '%s+(%s)' % (d, e)

def peephole(b):
    (p, p_ops), (x, x_ops) = b
    if p == 'LIVA' and x in ACCES_B:                 # adresse [base + d] + o deja calculee
        lvl, d, o = operandes(p_ops, 3)[:3]
        x_lvl, e = operandes(x_ops, 2)[:2]
        if lvl in ('', '-1') or x_lvl not in ('', '-1'):
            return None
        return '\t%s\t%s, %s, %s\n' % (B_VERS_C[x], lvl, d or '0', somme(o, e) or '0')
    if p not in ('LVA', 'LA', 'LQ'):
        return None
    lvl, d = operandes(p_ops, 2)[:2]
    if lvl in ('', '-1'):
        return None                                  # l'adresse du producteur est elle-meme sur la pile
    if x in ACCES_B:
        x_lvl, e = operandes(x_ops, 2)[:2]
        if x_lvl not in ('', '-1'):
            return None
        if p == 'LVA':
            return '\t%s\t%s, %s\n' % (x, lvl, somme(d, e))
        return '\t%s\t%s, %s, %s\n' % (B_VERS_C[x], lvl, d or '0', e or '0')
    if p == 'LIVA':
        return None
    if x in ACCES_C and p == 'LVA':
        x_lvl, e, o = operandes(x_ops, 3)[:3]
        if x_lvl not in ('', '-1'):
            return None
        return '\t%s\t%s, %s, %s\n' % (x, lvl, somme(d, e), o or '0')
    return None

SUPPRIMER = object()                               # reecriture en aucune ligne

def adresse_nulle(b):
    (p, p_ops), = b
    if p != 'LVA':
        return None
    lvl, d = operandes(p_ops, 2)[:2]
    if lvl in ('', '-1') and d in ('', '0'):
        return SUPPRIMER
    return None

def controle(b):
    if (b[0][0] == 'DUP' and b[4][0] == 'DUP' and b[1][0] in CHK and b[5][0] == b[1][0]
        and b[2][0] == 'CLT' and b[6][0] == 'CGT'
        and b[3] == ('BT', 'STANDARD.ce_raise_') and b[7] == ('BT', 'STANDARD.ce_raise_')):
        a1, a2 = re.sub(r'\s+', '', b[1][1]), re.sub(r'\s+', '', b[5][1])
        lst = re.sub(r'FST(_\d+)?$', lambda m: 'LST' + (m.group(1) or ''), a1)
        if lst != a1 and lst == a2:
            return '\t%s\t%s\n' % (CHK[b[1][0]], b[1][1])
    return None

def charge_etroite(b):
    ch, ops = b[0]
    if b[1][0] != 'LI' or b[2][0] != 'LI' or b[3][0] not in ('UBFX', 'SBFX'):
        return None
    lsb, w = entier(b[1][1]), entier(b[2][1])
    if lsb is None or w is None or lsb % 8 or w not in (8, 16, 32):
        return None
    if ch in CHARGE_B and lsb + w <= 8 * CHARGE_B[ch]:
        lvl, disp = operandes(ops, 2)[:2]
        return '\t%s\t%s, %s\n' % (ETROITE[(b[3][0], 'B')][w], lvl, decaler(disp, lsb // 8))
    if ch in CHARGE_C and lsb + w <= 8 * CHARGE_C[ch]:
        lvl, disp, ofs = operandes(ops, 3)[:3]
        return '\t%s\t%s, %s, %s\n' % (ETROITE[(b[3][0], 'C')][w], lvl, disp, decaler(ofs, lsb // 8))
    return None

def forme_immediate(b):
    if b[0][0] != 'LI' or b[1][0] != 'LI' or b[2][0] not in IMMEDIAT:
        return None
    lsb, w = entier(b[0][1]), entier(b[1][1])
    if lsb is None or w is None or not (0 <= lsb <= 63 and 1 <= w <= 64 and lsb + w <= 64):
        return None
    return '\t%s\t%d, %d\n' % (IMMEDIAT[b[2][0]], lsb, w)

REGLES = (('CHK', 8, controle), ('peephole', 2, peephole),
          ('charge etroite', 4, charge_etroite), ('forme immediate', 3, forme_immediate),
          ('adresse nulle', 1, adresse_nulle))

def reecrire(lignes):
    lignes = list(lignes)
    compte = dict((nom, 0) for nom, _, _ in REGLES)
    i = 0
    while i < len(lignes):
        b = [instr(l) for l in lignes[i:i + 8]]
        for nom, longueur, regle in REGLES:
            if len(b) >= longueur and None not in (x[0] for x in b[:longueur]):
                nouvelle = regle(b[:longueur])
                if nouvelle is SUPPRIMER:
                    lignes[i:i + longueur] = []
                    compte[nom] += 1
                    i = max(i - 1, 0)
                    break
                if nouvelle:
                    lignes[i:i + longueur] = [nouvelle]
                    compte[nom] += 1
                    i = max(i - 1, 0)                  # la ligne precedente peut se combiner
                    break
        else:
            i += 1
    return lignes, compte

if __name__ == '__main__':
    for nom in sys.argv[1:]:
        with open(nom, newline='') as f:
            lignes = [l.replace('\r', '') for l in f.readlines()]
        sortie, compte = reecrire(lignes)
        with open(nom, 'w') as f:
            f.writelines(sortie)
        print('%-24s CHK %6d   peephole %6d   charges etroites %6d   formes immediates %6d'
              '   adresses nulles %6d'
              % (nom, compte['CHK'], compte['peephole'], compte['charge etroite'],
                 compte['forme immediate'], compte['adresse nulle']))
