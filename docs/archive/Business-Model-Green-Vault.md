# GREEN VAULT - BUSINESS MODEL CANVAS

| **Projet :** Green Vault | **Date :** Novembre 2025 | **Version :** 1.0 |
|---|---|---|

## BUSINESS MODEL CANVAS

### **PARTENAIRES CLÉS** | **ACTIVITÉS CLÉS** | **PROPOSITION DE VALEUR** | **RELATION CLIENT** | **SEGMENTS CLIENTS**
---|---|---|---|---
**Partenaires stratégiques :**<br><br>• **Aave Protocol** : Protocole de lending principal, actifs composants tous les vaults<br><br>• **Privy** : Wallet management et onboarding utilisateurs<br><br>• **Oracles ESG** : Certification et validation critères ESG des projets (Chainlink, Impact Protocol)<br><br>• **ONG partenaires** : Vérification et gestion projets ESG financés (WWF, UNEP, etc.)<br><br>• **Échange crypto** : Conversion USDC (Stripe, Coinbase Commerce)<br><br>• **Infrastructure** : Providers nœuds Ethereum (Alchemy, Infura)<br><br>• **Universités** : Partenariats pédagogiques (reconnaissance académique) | **1. Gestion des Vaults :**<br>• Création/maintenance 3 vaults ERC-4626 Aave<br>• Monitoring APY temps réel Aave<br>• Rééquilibrage positions selon stratégie<br>• Optimisation rendements incentives<br><br>**2. Onboarding client :**<br>• Intégration Privy wallets<br>• Conversion fiat→USDC<br>• KYC/AML simplifié<br><br>**3. Gouvernance DAO :**<br>• Gestion tokens (Gold/Silver/Bronze)<br>• Cycles de vote mensuels<br>• Trésorerie surplus allocation<br><br>**4. Gestion ESG :**<br>• Validation projets ESG<br>• Suivi KPI impact (CO2, emplois, etc.)<br>• Reporting transparent | **Proposition clients :**<br><br>✓ **Performance** : Rendements nets 2-11% APY selon profil (défensif/modéré/dynamique)<br><br>✓ **Simplicité** : Interface épurée, onboarding < 5 min via Privy<br><br>✓ **Impact réel** : Financez projets ESG votés (environnement/social/gouvernance)<br><br>✓ **Gouvernance** : Votez directement les projets à financer via tokens<br><br>✓ **Transparence** : Dashboard temps réel impact ESG mesuré (CO2, emplois)<br><br>✓ **Gamification** : Tokens rewards, airdrops, challenges ESG<br><br>✓ **Sécurité** : 100% Aave (protocole établi), audits, oracles décentralisés<br><br>✓ **Alignement valeurs** : Être acteur du changement climatique/social | **Relations :**<br><br>• **Comunauté active** : Discord, Telegram, forum vote<br><br>• **Dashboard self-serve** : Utilisateurs indépendants<br><br>• **Support pédagogique** : Tutoriels, documentation, webinars<br><br>• **Engagement gamifié** : Challenges, quêtes ESG, achievements<br><br>• **Reporting impact** : Communications régulières KPI projets<br><br>• **Feedback loops** : Enquêtes satisfaction, suggestions utilisateurs | **Segments primaires :**<br><br>**1. Millénials/Gen-Z ESG-minded** (25-40 ans)<br>• Conscients climat/social<br>• Revenus moyens-hauts<br>• Tech-savvy, Web3-native<br>• Valeurs durabilité prioritaires<br><br>**2. Investisseurs impact** (35-55 ans)<br>• Fortune diversifiée<br>• Cherchent ROI + impact<br>• Aversion risque modérée<br>• ONG/fondations partenaires<br><br>**3. Étudiants/académiques** (18-30 ans)<br>• Projet pédagogique<br>• Apprentissage DeFi/DAO<br>• Engagement climat/social fort<br>• Bootstrapping investissement<br><br>**4. Entreprises B-Corp** (PME-ETI)<br>• Reporting ESG obligatoire<br>• Recherche fonds durables<br>• Marketing impact<br>• Transparence blockchain |

---

### **RESSOURCES CLÉS**

**Ressources techniques :**
• Smart contracts ERC-4626 vaults (Solidity)
• Intégration Aave Protocol SDK
• Backend Node.js + indexing (GraphQL)
• Dashboard React + Web3.js/Ethers.js
• Fork mainnet Ethereum local (Anvil)

**Ressources humaines :**
• Développeurs blockchain (2-3 FTE)
• Product manager / UX designer
• DevOps / Infrastructure
• Compliance / Legal (ESG, GDPR, MiCA)
• Community manager

**Ressources financières :**
• Budget infrastructure cloud
• Gas fees déploiement smart contracts
• Audits de sécurité externes
• Marketing initial & community building

**Ressources partenariales :**
• Accès APIs Aave, Privy, Chainlink
• Réseau ONG ESG
• Support universités (Alyra, Ackee)

---

### **CANAUX**

| **Canal** | **Acquisition** | **Activation** | **Rétention** |
|---|---|---|---|
| **Web/App** | Landing page SEO-optimisée | Dashboard Privy intégré | UX intuitive, rendements visibles |
| **Discord** | Annonces, community events | Onboarding bot, guides | Daily/weekly engagement, rewards |
| **Twitter/X** | Growth hacking, contests | Teasers, educational threads | Governance updates, impact reports |
| **Université** | Partenariats Alyra/Ackee | Workshops, hackathons | Badges académiques, progression |
| **Media Web3** | PR dans Bankless, Decrypt | Explainers técnicos | Thought leadership articles |
| **Événements** | Expos Web3 (EthCC, etc.) | Live demos vaults | Networking investisseurs impact |

---

### **STRUCTURE DE COÛTS**

| **Catégories** | **Coûts variables** | **Coûts fixes** |
|---|---|---|
| **Infrastructure** | Gas fees contrats, API calls (Aave, Chainlink) | Serveurs, nœuds Ethereum (~€500-1000/mois) |
| **Développement** | Audits externes sécurité, optimisations contract | 2-3 devs (~€15-25k/mois) |
| **Operations** | Incidents, monitoring, logs | DevOps full-time (~€4-6k/mois) |
| **Community** | Bounties, rewards, airdrops (% TVL) | Community manager (~€2-3k/mois) |
| **Compliance** | Audit legal, certification | Lawyer freelance (~€2-5k/mois) |
| **Marketing** | Publicités, contenu création | Basic website, social media (~€1-2k/mois) |
| **Miscellaneous** | Tooling software licenses | Software subscriptions (O'Reilly, etc.) (~€500/mois) |

**Coûts fixes totaux estimés Phase 1 :** ~€30-35k/mois

---

### **REVENUS**

| **Flux de revenus** | **Modèle** | **Montant** | **Notes** |
|---|---|---|---|
| **Fee Management Vaults** | Retrait 1% du rendement brut par vault | Variable selon TVL et APY | Exemple : 10M TVL, 6% APY brut = €60k/an |
| **Surplus DAO redistribution** | 30-58% de l'excédent APY si performance > objectif | Variable selon overperformance | Défensif : 1-1.5%, Modéré : 1-2%, Dynamique : 2-4% |
| **Token emissions** | Vente pré-allocation GV tokens (seed round optionnel) | Levée potentielle €500k-1M | Financement initial si levée externe |
| **Partnerships** | Frais intégration ONG, sponsors projets ESG votés | Marginal Phase 1 (~5-10% revenus) | Growth future avec adoption |
| **Yield optimization** | Flash loans, arbitrage intra-Aave (si applicable) | Faible Phase 1 (<1% revenus) | Exploration long terme |

**Revenus Phase 1 projections (TVL ramp-up) :**
- Mois 1-3 : ~€10-20k/mois (bootstrap/academic users)
- Mois 4-6 : ~€30-50k/mois (early adopters)
- Mois 7-12 : ~€80-150k/mois (if marketing/traction valide)

---

## SYNTHÈSE BUSINESS MODEL

### **Proposition de valeur clé**
Green Vault combine **performance financière stable** (2-11% APY nets), **impact ESG transparent et mesurable**, et **gouvernance communautaire active** via tokenomics gamifiée. Pour investisseurs cherchant ROI + responsabilité.

### **Avantage compétitif**
1. **Focalisation Aave** : Simplicité maximale, pédagogie, sécurité
2. **DAO intégrée** : Pas juste rendement, mais gouvernance réelle des projets
3. **ESG certifié** : Impact réel mesuré via oracles, ONG partenaires
4. **Tokenomics active** : Engagement gamifié, rewards, airdrops
5. **Projet académique** : Légitimité université, reconnaissance pédagogique

### **Viabilité financière**
- Model profitably à partir ~5-10M TVL (breakeven infrastructure)
- Scalabilité high : coûts fixes dominants, peu de coûts variables
- Trésorerie DAO auto-alimentée par surplus (financial sustainability)

### **Risques et mitigations**
| **Risque** | **Mitigation** |
|---|---|
| Volatilité Aave APY | Rééquilibrage dynamique, réserves de sécurité DAO |
| Adoption lente | Partenariats université, marketing community-driven |
| Compliance réglementaire | Monitoring MiCA/EU taxonomies, legal partners |
| Smart contract bugs | Audits externes, insurance, circuit breakers |
| ESG greenwashing | Oracles décentralisés, ONG partenaires indépendantes |

---

## PROCHAINES ÉTAPES AFFINAGE

- [ ] Chiffrer avec précision coûts development + operations Phase 1
- [ ] Modéliser CAC (Customer Acquisition Cost) par segment
- [ ] Détailler LTV (Lifetime Value) par profil utilisateur
- [ ] Projections financières 3 ans (cash flow, breakeven)
- [ ] Stratégie GTM (Go-To-Market) détaillée par segment
- [ ] Plan levée de fonds (si applicable)
- [ ] Étapes légales/compliance par juridiction