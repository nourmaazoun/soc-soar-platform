# Configuration de pfSense

pfSense sépare le laboratoire en trois zones, publie le serveur cible de la DMZ et applique le blocage décidé par Shuffle.

## Interfaces

| Interface | Réseau VMware | Adresse | Zone |
|---|---|---|---|
| WAN | pont (Wi-Fi) | DHCP | attaquant |
| LAN | LAN1 | 10.1.1.1/24 | SOC |
| OPT1 (DMZ) | LAN2 | 10.1.2.1/24 | serveur cible et IDS |

Sur le WAN, désactiver **Block private networks** et **Block bogon networks** : le WAN du laboratoire est lui-même un réseau privé.

Sur la DMZ, le DHCP est désactivé : les machines ont une adresse fixe.

## Redirection vers le serveur cible

**Firewall → NAT → Port Forward → Add**

| Champ | Valeur |
|---|---|
| Interface | WAN |
| Protocol | TCP |
| Destination | WAN address |
| Destination port range | 1 – 65535 |
| Redirect target IP | 10.1.2.100 (Metasploitable) |
| Filter rule association | Add associated filter rule |

> Tous les ports sont redirigés pour les besoins des tests. En production, seuls les services publiés (par exemple 80 et 443) le seraient.

## Blocage des attaquants

**1. Alias** — Firewall → Aliases → IP → Add

| Champ | Valeur |
|---|---|
| Name | `BLOCKED_IPS` |
| Type | Host(s) |
| Description | IPs bloquées automatiquement par Shuffle |

**2. Règle** — Firewall → Rules → WAN → Add (en **première position**)

| Champ | Valeur |
|---|---|
| Action | Block |
| Interface | WAN |
| Source | Single host or alias → `BLOCKED_IPS` |
| Destination | any |

Toute IP ajoutée à l'alias est alors bloquée avant d'atteindre la DMZ.

## API REST

Shuffle pilote pfSense par l'API REST v2 (paquet `pfSense-pkg-RESTAPI`).

1. Installer le paquet, puis **System → REST API → Settings** : activer l'API, autoriser l'interface **LAN** uniquement.
2. **System → REST API → Keys** : créer une clé pour Shuffle.
3. Chaque requête porte l'en-tête `x-api-key: <clé>`.

| Requête | Effet |
|---|---|
| `PATCH /api/v2/firewall/alias` | met à jour la liste des IP de `BLOCKED_IPS` |
| `POST /api/v2/firewall/apply` | applique les règles |

## Remise à zéro entre deux tests

1. Firewall → Aliases → `BLOCKED_IPS` : retirer l'IP de l'attaquant → **Save** → **Apply Changes**.
2. Sur la VM Snort : `sudo rm -f /var/lib/snort-shuffle/*` (mémoire anti-doublon du script).
