# Comment trouver l'onglet "Signing & Capabilities" dans Xcode

## Étapes à suivre :

1. **Dans le navigateur de projet (panneau de gauche)** :
   - Cliquez sur le **projet "Runner"** (la ligne bleue tout en haut, pas un fichier individuel)
   - Vous verrez alors deux colonnes dans le panneau principal :
     - À gauche : La liste des targets (vous devriez voir "Runner" et "RunnerTests")
     - À droite : Les paramètres du projet

2. **Sélectionnez le target "Runner"** :
   - Dans la colonne de gauche, cliquez sur **"Runner"** sous "TARGETS"
   - Vous verrez alors plusieurs onglets en haut du panneau principal :
     - **General** (sélectionné par défaut)
     - **Signing & Capabilities** ← C'est celui-là !
     - **Build Settings**
     - **Build Phases**
     - **Build Rules**
     - **Info**

3. **Cliquez sur l'onglet "Signing & Capabilities"** :
   - Vous verrez alors les options de signature automatique
   - Cochez "Automatically manage signing"
   - Sélectionnez votre Team : **J9P5HCMXJW**

## Si vous ne voyez toujours pas "Signing & Capabilities" :

Assurez-vous d'avoir sélectionné :
- ✅ Le **projet** "Runner" (pas un fichier) dans le navigateur
- ✅ Le **target** "Runner" dans la colonne de gauche des targets

Ne confondez pas :
- ❌ Le fichier "Info.plist" (qui montre l'onglet "Info")
- ✅ Le target "Runner" (qui montre l'onglet "Signing & Capabilities")

