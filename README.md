# PFA — Détection et réponse automatisée aux incidents de sécurité

Plateforme SOC/SOAR open source assurant la détection des intrusions, la réponse automatisée aux incidents et leur gestion collaborative.

Les alertes de l’IDS Snort déclenchent, via Shuffle, le blocage de la source sur le pare-feu pfSense et la création d’un incident dans TheHive, enrichi par Cortex et MISP. L’ensemble est déployé dans un environnement de laboratoire virtualisé sous VMware.

Projet de fin d'année — IIT Sfax, Département Informatique, 2025/2026

## Architecture

![Architecture de la plateforme SOC/SOAR](architecture.svg)

## Fonctionnement

1. **Kali** lance une attaque (scan, brute force, injection SQL) contre l'adresse publique de **pfSense**.
2. **pfSense** redirige le trafic vers **Metasploitable**, le serveur cible de la DMZ.
3. **Snort** détecte l'attaque et envoie une alerte à **Shuffle**.
4. **Shuffle** bloque l'attaquant sur **pfSense**, en moins d'une minute.
5. **Shuffle** crée l'incident dans **TheHive**, où les analystes le traitent.
6. **Cortex** analyse l'IP de l'attaquant et interroge **MISP** pour reconnaître les attaquants déjà connus.

## Résultats

| Scénario | Résultat |
|---|---|
| Scan Nmap | détecté, attaquant bloqué en moins d'une minute |
| Brute force telnet | détecté et bloqué |
| Injection SQL | détectée et bloquée |
| Gestion d'incident | alerte créée automatiquement dans TheHive |
| Threat Intelligence | IP analysée par Cortex et reconnue par MISP 

## Outils
pfSense · Snort · Shuffle · TheHive · Cortex · MISP · PostgreSQL · Grafana · Docker · VMware



## Démonstration

Un scan Nmap depuis Kali : les ports sont ouverts au premier passage, puis l'attaquant est bloqué et tous les ports deviennent filtrés.

![Scan avant et après le blocage](docs/screenshots/2-nmap-avant-apres-blocage.png)

L'alerte est créée automatiquement dans TheHive, puis Cortex reconnaît l'attaquant grâce à MISP.

![Alerte dans TheHive](docs/screenshots/4-thehive-alerte.png)
![Analyse Cortex et MISP](docs/screenshots/6-cortex-analyse-misp.png)

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| [`snort/`](snort/local.rules) | règles de détection personnalisées |
| [`scripts/`](scripts/snort_shuffle_watcher.sh) | script de liaison Snort → Shuffle |
| [`shuffle/`](shuffle/workflow.json) | workflow de réponse automatique |
| [`pfsense/`](pfsense/configuration-guide.md) | guide de configuration du pare-feu |
| [`thehive-cortex-misp/`](thehive-cortex-misp/integration-guide.md) | guide d'intégration TheHive, Cortex et MISP |
| [`docs/`](docs/rapport-technique.pdf) | rapport technique et captures |


