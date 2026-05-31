# SAMPLES/LOOP/ — exemples pour LOOP.PAS

Clone Pascal de la commande `loop` de ALPS — QMC SSE (Stochastic
Series Expansion) avec mise a jour par boucles pour Heisenberg AFM
isotrope S=1/2 sur reseau bipartite (chaine 1D ou carre 2D),
couplage J > 0.

## Lancement

```pwsh
.\LOOP.exe SAMPLES\LOOP\01_chain_L16_T05.parm
```

Genere `<basename>.out.txt` (+ `.out.xml` si `--write-xml`) dans
le meme repertoire que le fichier d entree.

## Liste des exemples

| Fichier | Reseau | L | T | Notes |
|---|---|---|---|---|
| `01_chain_L16_T05.parm` | chaine 1D | 16 | 0.5 | Test rapide, E/site ~ -0.34 |
| `02_chain_L16_lowT.parm` | chaine 1D | 16 | 0.1 | Test GS, E/site ~ -0.4433 (Bethe : -0.4431) |
| `03_chain_L32_T02.parm` | chaine 1D | 32 | 0.2 | Chi staggered eleve, quasi-LRO |
| `04_chain_L8_highT.parm` | chaine 1D | 8  | 2.0 | Regime haute T, E/site ~ 0 |
| `05_square_L8_T05.parm` | carre 2D | 8 | 0.5 | Heisenberg AFM 2D, ordre Neel naissant |
| `06_square_L8_lowT.parm` | carre 2D | 8 | 0.2 | E/site ~ -0.66 (Sandvik : -0.6694 inf) |
| `07_square_L4_T10.parm` | carre 2D | 4 | 1.0 | Petit, test rapide |
| `08_square_L16_T03.parm` | carre 2D | 16 | 0.3 | Grand systeme, m_stag^2 ~ 0.094 inf |
| `09_chain_alps.in.xml` | chaine 1D | 16 | 0.1 | Demo format XML ALPS |

## Theorie

Hamiltonien :
H = J * sum_{<i,j>} S_i . S_j,   J > 0 (AFM)

Decomposition de Sandvik :
H = J * NB / 4 - J * sum_b H_b
ou H_b = 1/4 - S_i . S_j a element de matrice 1/2 sur les paires
antiparalleles (0 sur paires paralleles).

### Estimateurs SSE

- Energie : `<H> = -<n>/beta + J * NB / 4` ou n est le nombre
  d operateurs non-identite dans la string.
- Chaleur specifique : `C = <n^2> - <n>^2 - <n>`.
- Susceptibilite uniforme : `chi_u = (beta / N) * <M_z^2>`
  (M_z conservee → estimateur statique exact).
- Susceptibilite staggered : `chi_s = (beta / N) * <M_stag^2>`
  (approximation statique, pas l integrale temps imaginaire).

### Mise a jour par boucles (Heisenberg isotrope)

Algorithme deterministe : a chaque vertex la boucle relie les
deux legs de la meme tranche temporelle (graphe 0<->1 en bas,
2<->3 en haut). Chaque boucle est flippee avec probabilite 1/2.
Le type d operateur (diag <-> off-diag) bascule automatiquement
si la parite des flips entre haut et bas du vertex change.

Sites non touches par aucun operateur (rare a basse T) : spin
flippe independamment avec prob 1/2.

## References

- A. W. Sandvik, "Computational Studies of Quantum Spin Systems",
  AIP Conf. Proc. 1297, 135 (2010). arXiv:1101.3281.
  Pseudo-code des updates SSE + loop pour Heisenberg.
- A. W. Sandvik, S. Daul, R. R. P. Singh, D. J. Scalapino,
  Phys. Rev. Lett. 89, 247201 (2002).
- ALPS library, "loop" application, https://alps.comp-phys.org/

## Limites de cette implementation

- S=1/2 seulement (pas S=1, etc.).
- Heisenberg isotrope seulement (pas XXZ general).
- Reseaux bipartites seulement (pas de frustration ; J < 0
  est rejette avec un avertissement).
- Tailles : L <= 32 (carre 2D : 32x32 = 1024 sites max), string
  d operateurs M <= 4000 (recompile MAX_M pour aller plus loin).
- Bins de mesure : 32 max (recompile MAX_BINS pour plus de
  precision statistique).
- Pas de mesure d observable Green G(tau), pas de structure
  factor S(q) (estimateurs simples uniquement).
