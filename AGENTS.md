# Instructions pour Codex — Disasterbound

Lis `GAME_DESIGN.md` et `TECHNICAL_SPEC.md` **avant toute modification**. Ils constituent la référence produit et technique. En cas de contradiction ou d'ambiguïté, pose une question ciblée plutôt que d'inventer une décision majeure.

## Mission

Développer progressivement **Disasterbound**, un jeu PC Godot 4 / GDScript, 2D vue du dessus, pixel art coloré, fondé sur une simulation d'incendie et la défense automatique d'une zone habitée. **Priorité : rendu agréable, lisibilité et boucle de jeu testable.**

## Règles de travail

1. **Une tâche / un jalon à la fois.** N'implémente pas des fonctionnalités futures « au cas où ».
2. **Économie de tokens :** réponses courtes, modifications ciblées, pas de longs comptes rendus ni de refactorisation générale non demandée.
3. **Ne réécris pas** des fichiers sans nécessité. Préserve les modifications et choix existants ; examine l'état du dépôt avant d'agir.
4. Utilise **Godot 4.x + GDScript**, sans React ni framework web.
5. Sépare **simulation, rendu, UI et données**. La couleur d'un pixel affiché ne doit jamais être la source de vérité des règles de jeu.
6. Favorise les systèmes natifs Godot et les dépendances minimales. N'ajoute pas de plugin sans justification explicite.
7. Centralise les paramètres d'équilibrage (portée, cadence, combustible, propagation, HP, etc.). Évite les valeurs magiques disséminées.
8. Évite un `Node` par cellule de terrain : la grille logique doit utiliser des structures de données adaptées.
9. Maintiens le style **pixel art moderne, très coloré, animé et lisible** : zones géographiques cohérentes, contours organiques, détails décoratifs ; pas de damier de carrés sans intention artistique.
10. Ne copie pas les assets, cartes, codes ou éléments propriétaires de jeux de référence.
11. Pour toute nouvelle mécanique, implémente d'abord la **version la plus simple testable**, puis améliore-la à partir des retours.
12. Ne crée pas d'intégration Steam, d'autres campagnes, de système multijoueur ou d'éditeur de niveaux sans demande explicite.

## Processus avant de coder

- Vérifie la structure du dépôt et les fichiers existants.
- Identifie le jalon demandé et les critères d'acceptation.
- Si un détail manque, choisis une valeur provisoire **configurable** lorsqu'elle est sans risque, et indique-la brièvement ; demande validation pour un changement majeur de gameplay ou d'architecture.
- Donne un plan très court uniquement si la tâche le justifie, puis exécute.

## Processus après modification

- Vérifie la cohérence des scènes, scripts, chemins et ressources.
- Si Godot est disponible, lance une vérification headless/import ou un test approprié ; sinon, indique clairement que le test n'a pas pu être exécuté.
- Rapporte en quelques lignes : **fait / fichiers principaux / comment tester / limites éventuelles**.
- **Arrête-toi** après le jalon demandé. Ne commence pas le suivant spontanément.

## Première mission recommandée (à lancer séparément)

> Implémente uniquement le **jalon 0** de `TECHNICAL_SPEC.md` : initialise un projet Godot 4 minimal et exécutable, avec scène principale, caméra 2D et fond provisoire, sans simulation, sans arbre technologique, sans système de combat. Vérifie le lancement si possible, puis arrête-toi. Ne réalise pas encore le jalon 1.

## Priorités en cas d'arbitrage

1. Jeu fonctionnel et testable.
2. Clarté du rendu et expérience visuelle.
3. Simplicité du code et facilité d'itération.
4. Performance mesurée, pas optimisation prématurée.
5. Extensibilité raisonnable, sans surarchitecture.
