# Disasterbound

Jeu PC 2D en vue du dessus, développé avec Godot et GDScript.

## Lancer le projet

1. Ouvrir le gestionnaire de projets de Godot 4.7.2 stable, édition standard.
2. Cliquer sur **Importer** et sélectionner le fichier `project.godot` à la racine du dépôt.
3. Ouvrir le projet et appuyer sur **F5** pour lancer la scène principale.

La fenêtre s’ouvre en 1280 × 720 et affiche la carte **Le Hameau**. Le rendu conserve son format 16:9 avec une mise à l’échelle entière de la résolution interne de 640 × 360.

- **Molette** pour zoomer par paliers de ×1 à ×3, autour du pointeur.
- **ZQSD / WASD** pour déplacer la caméra lorsque la carte est agrandie.
- **Espace** pour lancer ou mettre en pause la propagation.
- **Clic gauche** sur la végétation pour allumer un foyer.
- **R** pour revenir à la carte initiale, en pause.

Le foyer préréglé au nord-ouest et les réglages du feu sont accessibles dans la ressource **Configuration** du nœud `FirePreview`.

## Vérifier en mode headless

Depuis la racine du dépôt, avec l’exécutable console de Godot disponible sous le nom `godot` dans le PATH, exécuter les deux commandes suivantes. Au besoin, remplacer `godot` par le chemin de cet exécutable.

```powershell
godot --headless --path . --editor --import
godot --headless --path . --quit-after 2
godot --headless --path . --script res://tests/fire_simulation_test.gd
```
