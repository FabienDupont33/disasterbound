# Disasterbound — Spécification technique

> v0.1 — architecture cible pour un premier prototype, à faire évoluer selon les tests. Ce document ne signifie pas que les fonctionnalités futures doivent être développées immédiatement.

## 1. Stack retenue

| Domaine | Choix |
|---|---|
| Moteur | Godot 4.x stable (version exacte épinglée dans le projet) |
| Langage | GDScript typé quand utile |
| Monde | 2D, vue du dessus |
| Style | Pixel art moderne, coloré et animé |
| Rendu initial | Godot Compatibility, à réévaluer si un effet l'exige |
| Cible initiale | Windows desktop ; Steam à terme |
| Versionnement | Git ; textes et scènes Godot autant que possible |
| Sauvegardes | Données versionnées dans `user://`, validation à la lecture |

Pas de React, pas de moteur 3D, pas de dépendance externe inutile. Aucun SDK Steam nécessaire au prototype.

## 2. Principes d'architecture

1. **Simulation ≠ affichage.** Le terrain et le feu sont représentés par des données ; le rendu les lit sans en être la source de vérité.
2. **Grille invisible, paysages continus.** Les cellules ne doivent pas être dessinées comme des cases apparentes ; les zones sont organiques, cohérentes et décorées.
3. **Systèmes séparés.** Monde, simulation du feu, défenses, objectifs, UI et progression communiquent via interfaces simples/signaux.
4. **Données configurables.** Éviter les constantes d'équilibrage dispersées : ressources Godot (`.tres`), objets `Resource` ou fichiers de configuration validés.
5. **Une campagne à la fois.** Garder les noms et les données extensibles à d'autres catastrophes, sans construire de framework abstrait prématuré.
6. **Rendu remplaçable.** La simulation ne dépend ni des sprites, ni des shaders, ni des particules.
7. **Performance mesurée.** Ne pas créer un `Node` par cellule de simulation ; préférer des tableaux compacts et une visualisation agrégée.

## 3. Organisation suggérée

```text
res://
  project.godot
  scenes/
    main.tscn
    prototype_world.tscn
    ui/
    defenses/
  scripts/
    core/
    world/
    fire/
    defenses/
    objectives/
    progression/
    ui/
  resources/
    maps/
    balance/
    campaigns/
  art/
    terrain/
    details/
    fire/
    water/
    buildings/
    ui/
  audio/
  tests/
```

Structure indicative : créer uniquement les dossiers nécessaires au jalon courant. Les chemins et noms définitifs doivent rester cohérents, sans multiplication de couches inutiles.

## 4. Terrain et carte

### Données

Une carte contient : dimensions logiques, résolution de grille, zones de terrain, masques d'obstacles/placement, emplacements d'eau, zone(s) protégée(s), conditions initiales et sources de feu.

Chaque cellule logique contient au minimum :
- `terrain_type` ;
- `fuel` ;
- `moisture` ;
- `temperature` ou `heat` ;
- `fire_intensity` ;
- `burn_state`.

Les propriétés doivent être définies dans des plages documentées, avec conversions et bornes explicites. Les coordonnées monde ↔ grille doivent passer par un seul module.

### Affichage

- Les zones ont des contours naturels (formes dessinées/masques ou contours générés avec contrôle artistique).
- Le rendu initial peut utiliser `TileMapLayer`, `ImageTexture` ou polygones/textures selon le résultat du prototype. **Ne pas imposer un shader complexe d'emblée.**
- Les détails de surface sont des sprites ou motifs visuels reproductibles avec graine fixe, pour éviter un changement de décor à chaque lancement.
- Les bâtiments sont des éléments visuels liés à une **zone logique protégée** ; un village peut avoir une seule jauge HP.
- Les contraintes de placement sont issues des données du terrain, pas de la couleur affichée à l'écran.

## 5. Simulation de feu

### Cadence

- Utiliser un **pas de simulation fixe** indépendant du framerate visuel, avec accumulateur si nécessaire.
- Le pas exact sera réglé selon fluidité, stabilité et performance ; éviter les calculs complets à chaque frame graphique.
- Une graine pseudo-aléatoire contrôlable doit permettre des tests reproductibles.

### Règles de base

À chaque pas :
1. Identifier les cellules actives et leurs voisines pertinentes.
2. Calculer le transfert de chaleur et l'influence du vent/humidité.
3. Déclencher l'inflammation si les conditions sont remplies.
4. Consommer du combustible et faire évoluer l'intensité.
5. Refroidir ou éteindre les cellules arrosées.
6. Marquer les zones épuisées comme brûlées ; notifier le rendu des cellules modifiées.

Éviter les mises à jour dépendantes de l'ordre de parcours : utiliser des états temporaires/double buffering lorsque nécessaire. Une cellule non combustible ne doit pas s'enflammer. Une cellule sans combustible ne doit pas brûler indéfiniment.

### Difficulté et survie

Les variations météo et sources de feu externes sont **configurables par carte**. Le mécanisme exact d'alimentation d'un incendie durable est une hypothèse à tester ; ne pas le cacher dans une multiplication artificielle des dégâts.

## 6. Défenses et dégâts

### Canon à eau initial

- Placé en préparation uniquement pour le premier jalon.
- Portée, cadence, puissance, rayon d'arrosage, HP et règles d'alimentation paramétrables.
- Ciblage automatique d'une cellule/zone en feu dans sa portée ; comportement déterministe à état identique.
- L'eau modifie les **données de simulation** (chaleur, humidité, intensité), pas seulement l'animation.
- HP diminuent au contact d'une chaleur dangereuse ; équipement détruit = inactif jusqu'à la tentative suivante.
- Prévoir une interface de statistiques pour les futures améliorations indépendantes ; ne pas implémenter l'arbre entier dans le prototype.

### Zone habitée

- Un `ProtectedZone` logique avec HP max, HP actuels et résistance configurable.
- Dégâts reçus selon l'exposition réelle au feu ; pas selon une simple minuterie.
- Défaite quand les HP atteignent zéro.
- La représentation graphique peut inclure plusieurs maisons et états de dégâts sans multiplier les jauges logiques.

## 7. États du jeu

```text
PREPARATION -> RUNNING -> DEFEAT -> PREPARATION
```

- **PREPARATION** : placement, inspection, bouton Démarrer ; le feu ne progresse pas.
- **RUNNING** : simulation active, défenses automatiques, HUD.
- **DEFEAT** : arrêt propre de la simulation, bilan simple, bouton Recommencer.

Les compétences actives, bonus temporaires, victoire/validation de niveau et sauvegardes permanentes seront ajoutés dans des jalons ultérieurs.

## 8. Progression et données persistantes (phase ultérieure)

Prévoir des identifiants stables de campagne (`fire`, `chemical`, etc.), carte et technologie.

Structure conceptuelle :

```json
{
  "schema_version": 1,
  "campaigns": {
    "fire": {
      "research_points": 0,
      "unlocked_maps": ["fire_01"],
      "technology_levels": {}
    }
  }
}
```

Ce JSON est un **exemple de schéma futur**, pas une exigence de création immédiate. Une campagne ne doit jamais dépenser les points d'une autre. Prévoir validation des valeurs et migration simple des versions.

## 9. Animation et performance

- Foyers pixelisés rouges/orange/jaunes animés et scintillants, à échelle de pixel cohérente.
- Éviter un nœud et une particule coûteuse pour chaque pixel : privilégier un rendu groupé/texture mise à jour par zones modifiées, complété de quelques effets localisés.
- Rafraîchir les visuels à un rythme indépendant du pas de simulation.
- Utiliser des ressources graphiques réutilisables, une palette contrôlée et un zoom sans flou non désiré.
- Cible initiale : 60 FPS sur machine de développement ; **mesurer** avant d'optimiser. Documenter taille de carte et nombre de cellules testées.
- Aucun effet visuel ne doit masquer durablement l'état des foyers, des canons ou du village.

## 10. Critères techniques du prototype

- Le projet s'ouvre sans erreur dans la version Godot choisie.
- La scène principale se lance depuis l'éditeur.
- Carte agréable à regarder, avec zones naturelles non quadrillées et éléments décoratifs.
- Un canon se place légalement ; les placements interdits sont clairement signalés.
- Le feu démarre au clic sur Démarrer et se propage sur combustible.
- L'eau du canon agit réellement sur la simulation.
- Les équipements et la zone habitée subissent des dégâts ; la défaite fonctionne.
- Le bouton Recommencer restaure les données initiales sans états résiduels.
- Les paramètres majeurs sont centralisés ; aucun avertissement bloquant ou erreur récurrente dans la console.

## 11. Plan d'implémentation sobre en tokens

**Jalon 0 — Squelette :** projet Godot, scène de démarrage, caméra, documentation d'exécution. Validation : ouverture et lancement.

**Jalon 1 — Carte visuelle :** une carte dessinée avec forêt/prairie, eau, terre, village, détails, contours soignés. Validation : capture et revue artistique. **Ne pas implémenter le feu.**

**Jalon 2 — Feu :** données de terrain + simulation + foyers animés + zones carbonisées. Validation : propagation lisible, non-combustibles respectés.

**Jalon 3 — Canon :** placement, ciblage, eau, extinction. Validation : l'emplacement modifie réellement l'issue de la simulation.

**Jalon 4 — Enjeu :** HP du village et du canon, défaite, recommencer, HUD minimal.

**Jalon 5 — Boucle de progression :** une carte validable, points de recherche, quelques niveaux indépendants du canon, sauvegarde.

**Plus tard :** autres cartes, compétences actives, bonus temporaires, équilibrage, autres catastrophes, Steam.

À la fin de chaque jalon : lancer le projet si l'environnement le permet, vérifier les erreurs, résumer les fichiers changés, fournir un test manuel court et **s'arrêter**. Ne pas anticiper le jalon suivant sans demande.

## 12. Évolutivité du rendu

Changer les sprites, textures, palette et effets au sein de Godot doit rester relativement simple grâce à la séparation simulation/rendu. Changer de renderer Godot peut demander des ajustements de shaders. Changer de **moteur de jeu** (Godot vers Unity, etc.) impliquerait une réécriture importante : ne pas présenter cela comme un simple changement de configuration.
