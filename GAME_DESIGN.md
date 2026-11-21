# Disasterbound — Game Design Document

> Statut : document de cadrage initial (v0.1). Langue de travail : français. Les chiffres d'équilibrage sont provisoires.

## 1. Vision

**Disasterbound** est un jeu PC de défense de zones, vu strictement du dessus, au style pixel art coloré et animé. Le joueur prépare un dispositif de défense pour protéger une habitation ou un village contre une catastrophe qui se propage dans un paysage cohérent. Il déclenche lui-même la simulation, puis observe ses équipements automatiques et intervient occasionnellement avec des compétences actives à temps de recharge.

Le plaisir repose sur :
- une catastrophe vivante, visible et compréhensible, qui modifie le terrain ;
- un placement libre mais contraint par la géographie et les ressources locales ;
- une **progression technologique permanente**, forte et détaillée, propre à chaque catastrophe ;
- des paliers de difficulté marqués entre les cartes ;
- le sentiment de devenir surpuissant en revenant sur les premières cartes.

**Priorité de production :** un monde très agréable à regarder, lisible, vivant et coloré. Le pixel art est un choix artistique assumé, pas une excuse pour des graphismes provisoires.

## 2. Structure des campagnes

- Écran d'accueil : sélection d'une catastrophe.
- **Incendie** : première campagne développée, accessible au lancement.
- **Contamination chimique** : campagne future envisagée, verrouillée jusqu'à la fin de la campagne Incendie.
- D'autres catastrophes (végétation invasive, gel, etc.) sont des idées, **pas des engagements de contenu**.
- Chaque campagne a ses cartes, règles, équipements, compétences et **arbre technologique indépendant**. Une campagne nouvellement débloquée repart de zéro dans sa progression propre ; les progrès des campagnes précédentes restent sauvegardés.
- L'architecture doit permettre l'ajout ultérieur de campagnes, **sans implémenter leur gameplay dès maintenant**.

## 3. Boucle de jeu

1. Choisir la campagne et une carte accessible.
2. Investir les points de recherche **de cette campagne** dans des améliorations permanentes ciblées.
3. Entrer en phase de préparation : examiner le terrain et placer les équipements disponibles, librement sous réserve des contraintes.
4. Appuyer sur **Démarrer** : la catastrophe commence ; la simulation se déroule en temps réel, sans pause tactique prévue comme mécanique centrale.
5. Les équipements agissent automatiquement. Le joueur utilise ponctuellement des compétences actives à cooldown ; elles aident sans suffire à gagner seules.
6. Des bonus temporaires modestes peuvent être proposés pendant la tentative ; ils soutiennent le build sans le transformer radicalement.
7. À la destruction de la zone protégée, afficher le bilan, attribuer les points, proposer une nouvelle tentative ou une autre carte.

### Survie et validation des cartes

- Sur les cartes classiques, l'objectif est de **tenir le plus longtemps possible** en protégeant une zone habitée.
- Une carte doit avoir un **seuil de validation** pour débloquer la suivante, même si la survie peut continuer au-delà ; la durée et les règles précises restent à tester.
- Certaines cartes spéciales, de type « boss », pourront proposer un objectif différent (ex. protéger une installation pendant une crise particulière).
- La difficulté augmente fortement d'une carte à la suivante, par sa topographie, ses sources d'eau, son combustible, ses vents et ses contraintes de placement — pas uniquement par des multiplicateurs.
- Les cartes anciennes **ne s'adaptent pas** au niveau du joueur : elles deviennent faciles avec les améliorations.
- Les cartes avancées doivent être plus rentables en points de recherche ; éviter que farmer le niveau 1 soit optimal. Formule à équilibrer.

## 4. Première campagne : Incendie

### 4.1 Terrain et monde

- Carte vue du dessus composée de **zones géographiques cohérentes** : prairie, forêt, végétation sèche, terre nue, roche, eau, zone habitée.
- Contours organiques et lisibles ; **pas** de mosaïque de pixels aléatoires sans logique paysagère.
- Détails décoratifs (petits arbres dessinés, buissons, pierres, chemins, maisons) superposés aux zones ; ils ne sont pas nécessairement des entités simulées.
- Une zone habitée peut être représentée visuellement par plusieurs maisons mais posséder une jauge de vie logique commune.
- Les sources d'eau et les obstacles géographiques ont une incidence sur les choix de placement et/ou l'efficacité des défenses.

### 4.2 Propagation du feu

- La simulation fonctionne sur une **grille logique invisible**, distincte du rendu.
- Les cellules portent au minimum : type de terrain, combustible, humidité, chaleur/température, intensité du feu et état de combustion.
- Le feu se propage vers les zones combustibles voisines, influencé par le vent, l'humidité et le combustible disponible.
- Le feu consomme le combustible ; les surfaces brûlées changent d'apparence et ne brûlent pas indéfiniment.
- Le système doit permettre à terme des braises ou départs secondaires, mais ce n'est **pas requis pour le premier jalon**.
- La difficulté croissante doit provenir de conditions explicables (vent, sécheresse, foyers extérieurs, topographie), pas d'apparitions arbitraires invisibles.
- **Question à prototyper :** comment entretenir une pression de feu durable pour un mode survie sans produire un comportement artificiel ? Ne pas figer cette réponse avant les essais.

### 4.3 Rendu du feu

- Foyers **animés**, composés de pixels rouges, orange et jaunes qui scintillent ; variation d'intensité et contours mouvants.
- Plusieurs foyers peuvent se rejoindre en fronts continus, sans que le terrain devienne une simple nappe monochrome.
- La propagation doit être visuellement observable ; les zones éteintes et carbonisées sont immédiatement identifiables.
- Effets d'eau, éclaboussures, vapeur, fumée et braises : sobres et lisibles, introduits progressivement.
- Préserver la lisibilité du village, des équipements, des zones dangereuses et des HP même lors d'un incendie intense.

## 5. Défenses et interactions

### 5.1 Canon à eau (premier équipement)

- Placement libre sur les surfaces autorisées.
- Acquisition et **nombre maximal disponible** déterminés par l'arbre technologique permanent ; pas de boutique de construction obligatoire pendant la tentative.
- Ciblage automatique de foyers à portée ; interaction avec la surface : refroidir, humidifier, diminuer l'intensité du feu.
- L'efficacité peut dépendre de la proximité d'une source d'eau : règle exacte à tester, avec retour visuel clair pour le joueur.
- **Destructible** : HP, dégâts thermiques, destruction pour la tentative en cours seulement ; récupéré à la tentative suivante.
- Technologie améliorée **indépendamment** : quantité, portée, cadence, puissance d'extinction, surface arrosée, HP/résistance, etc.
- Variantes possibles à terme : jet continu, projectile et dispersion. Pour le prototype, implémenter **une seule variante lisible** avant d'ajouter les autres.

### 5.2 Autres défenses et terrain

- Idées futures : coupe-feu, bulldozer, pluie artificielle, intervention aérienne.
- Les modifications de terrain (débroussaillage, tranchées, etc.) sont **à étudier** ; elles ne sont pas toutes validées ni requises au premier prototype.
- Ne pas inventer un réseau hydraulique complexe avant d'avoir validé le jeu de base.

### 5.3 Compétences actives

- Déblocage et amélioration via l'arbre de campagne ; cooldowns visibles.
- Exemples potentiels : largage d'eau, intervention d'urgence, création ponctuelle de coupe-feu.
- **Rôle secondaire :** corriger une faiblesse ou sauver une situation, sans pouvoir gagner une partie avec les seules compétences actives.
- Les défenses et le placement doivent rester les moteurs principaux de la réussite.

## 6. Progression

### 6.1 Arbre permanent (système principal)

- Points de recherche gagnés après les tentatives, liés à la carte et aux performances.
- Chaque équipement dispose de branches de statistiques **indépendantes** (ex. nombre, portée, cadence, puissance, résistance).
- Coûts croissants, effets immédiatement perceptibles ; valeurs configurables et équilibrables.
- Les zones habitées peuvent recevoir des améliorations modestes : HP, résistance au feu, protection légère. **Elles ne doivent jamais devenir invincibles** ni remplacer les défenses.
- Les points et déblocages sont **isolés par campagne**.

### 6.2 Bonus temporaires (système d'appoint)

- Choix occasionnels pendant une tentative, modestes et proportionnés à la difficulté.
- Exemples : petite hausse de portée, de cadence ou de résistance.
- **Pas de synergies « game changer » ni de puissance démesurée due à la chance** : la progression permanente reste dominante.
- Les bonus disparaissent à la fin de la tentative.
- Déclencheurs, fréquence, raretés et plafonds restent à tester.

## 7. Direction artistique et UX

- Pixel art moderne **très coloré**, légèrement rétro, sans rendu terne.
- Vue du dessus, zoom possible ; silhouettes, contours et contrastes clairs.
- Grandes zones naturelles aux formes cohérentes ; petits motifs décoratifs intégrés aux surfaces.
- Animation constante mais légère : scintillement du feu, eau, petites réactions du décor.
- UI propre, lisible et moderne avec touches rétro ; informations prioritaires : HP protégés, temps, niveau, état de préparation, équipements disponibles, cooldowns.
- Ne pas confondre « low-res » avec « peu soigné » : palette, échelle des pixels et animation doivent rester cohérentes.
- La capture de référence sert d'**inspiration visuelle**, pas d'autorisation de recopier des assets ou des cartes d'un autre jeu.

## 8. Critères de réussite du premier prototype

Une **seule** petite carte cohérente et colorée doit permettre de :
1. distinguer clairement prairie/forêt, terre, eau et zone habitée ;
2. voir des détails décoratifs bien intégrés, sans grille apparente ;
3. placer un canon sur une zone autorisée ;
4. démarrer volontairement la simulation ;
5. voir des foyers animés se propager et modifier le terrain ;
6. voir le canon éteindre/refroidir localement le feu ;
7. voir les HP de la zone habitée et du canon diminuer s'ils sont atteints ;
8. perdre lorsque les HP de la zone habitée atteignent zéro ;
9. relancer une tentative sans redémarrer l'application.

**Hors périmètre du premier prototype :** campagne complète, autres catastrophes, arbre technologique complet, bonus temporaires, compétences actives, Steamworks, multijoueur, génération procédurale complexe.

## 9. Points ouverts (ne pas les traiter comme des décisions)

- Durée cible des parties, seuils de validation et nombre de cartes.
- Modèle exact d'alimentation des canons par l'eau.
- Source et intensification des incendies en survie longue.
- Interventions possibles après le lancement en dehors des compétences actives.
- Règles détaillées de destruction et de réparation des défenses.
- Courbe de récompenses, coûts et plafonds technologiques.
- Méthode définitive de rendu des surfaces et du feu, à choisir après essai visuel/performance.
