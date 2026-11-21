# Disasterbound

Jeu PC 2D en vue du dessus, développé avec Godot et GDScript.

## Lancer le projet

1. Ouvrir le gestionnaire de projets de Godot 4.7.2 stable, édition standard.
2. Cliquer sur **Importer** et sélectionner le fichier `project.godot` à la racine du dépôt.
3. Ouvrir le projet et appuyer sur **F5** pour lancer la scène principale.

**Le Hameau** reste entièrement visible dans un cadre 16:9. La caméra s’ajuste automatiquement à la carte.

- **Clic gauche** en préparation pour placer le canon présélectionné. **1** active ou désactive l’aperçu.
- **Espace** pour lancer ou mettre en pause la propagation.
- **Clic gauche** sur la végétation après le premier démarrage pour allumer un foyer de test.
- **R** pour revenir à la préparation et récupérer le canon.

Le foyer préréglé au nord-ouest et les réglages du feu sont accessibles dans la ressource **Configuration** du nœud `FirePreview`.

## Vérifier en mode headless

Depuis la racine du dépôt, avec l’exécutable console de Godot disponible sous le nom `godot` dans le PATH, exécuter les deux commandes suivantes. Au besoin, remplacer `godot` par le chemin de cet exécutable.

```powershell
godot --headless --path . --editor --import
godot --headless --path . --quit-after 2
godot --headless --path . --script res://tests/fire_simulation_test.gd
godot --headless --path . --script res://tests/water_cannon_test.gd
```
