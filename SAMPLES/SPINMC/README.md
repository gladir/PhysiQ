# SPINMC : Exemples

Scripts d'exemple pour `SPINMC.EXE` (clone de la commande `spinmc` de
la bibliotheque ALPS - Algorithms and Libraries for Physics Simulations).

Chaque fichier `.parm` decrit une simulation Monte-Carlo classique
d'un modele de spin sur reseau carre 2D periodique.

## Execution

Depuis le dossier racine du projet :

```
SPINMC.EXE SAMPLES\SPINMC\01_ising_lowT.parm
SPINMC.EXE --write-xml SAMPLES\SPINMC\03_ising_critical.parm
SPINMC.EXE --time-limit 30 SAMPLES\SPINMC\06_potts_q8.parm
```

Chaque execution produit un `<base>.out.txt` (toujours) et, avec
`--write-xml`, un `<base>.out.xml` compatible avec `spinmc_evaluate`
d'ALPS.

## Index des exemples

| Fichier | Modele  | T      | Update    | Attendu |
|---------|---------|--------|-----------|---------|
| `01_ising_lowT.parm`       | Ising   | 1.5     | local    | Ordonne (\|M\| ~ 1) |
| `02_ising_highT.parm`      | Ising   | 4.0     | local    | Desordonne (\|M\| ~ 0) |
| `03_ising_critical.parm`   | Ising   | 2.269   | cluster  | Critique (U ~ 0.61) |
| `04_ising_field.parm`      | Ising   | 2.0     | local    | Champ H = 0.1 |
| `05_potts_q3.parm`         | Potts 3 | 0.995   | cluster  | Critique Potts q=3 |
| `06_potts_q8.parm`         | Potts 8 | 0.745   | cluster  | Transition 1er ordre |
| `07_xy_lowT.parm`          | XY      | 0.4     | local    | Quasi-ordre KT |
| `08_xy_highT.parm`         | XY      | 1.5     | local    | Desordonne |
| `09_ising_metropolis.parm` | Ising   | 2.269   | local    | Comparaison vs cluster |
| `10_ising_alps.in.xml`     | Ising   | 2.269   | cluster  | Format XML ALPS |

## Cles supportees dans les fichiers .parm

```
LATTICE        = "square lattice"
MODEL          = "Ising" | "Potts" | "XY"
UPDATE         = "local" | "cluster"
L              = taille du cote (2..64)
Q              = nombre d etats Potts (2..8)
T              = temperature
J              = couplage (J>0 ferro, J<0 antiferro)
H              = champ externe (Ising)
THERMALIZATION = balayages de pre-equilibrage
SWEEPS         = balayages de mesure
SEED           = graine RNG
```

Commentaires : `#` en debut de ligne ou en fin de ligne.

## Reperes theoriques (reseau carre 2D infini)

- **Ising** : T_c = 2 / ln(1 + sqrt(2)) ≈ 2.2692, U* ≈ 0.611, E(T_c)/N = -sqrt(2).
- **Potts q**: T_c = 1 / ln(1 + sqrt(q)). Pour q <= 4 : transition continue ;
  pour q > 4 : transition du 1er ordre (bistabilite a T_c).
- **XY** : transition de Kosterlitz-Thouless a T_KT ≈ 0.893.
  Pas de vraie aimantation finie (Mermin-Wagner) ; pour L fini
  on observe une pseudo-aimantation qui chute pres de T_KT.

## Notes pratiques

- L'algorithme `cluster` (Wolff) est tres efficace pres de Tc pour
  Ising et Potts. Pour XY il n'est pas implemente (repli automatique
  sur Metropolis avec avertissement).
- Avec un L grand (>=32) et `cluster`, prevoir SWEEPS >= 10000 pour
  une statistique decente (~32 bins de 300+ mesures).
- Le format `.in.xml` est un sous-ensemble minimal de la sortie de
  `parameter2xml` : balises `<PARAMETER name="...">VALEUR</PARAMETER>`.
