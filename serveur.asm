# ============================================================================
#  serveur.asm — Serveur web minimaliste écrit en ASSEMBLEUR x86-64 (Linux)
# ----------------------------------------------------------------------------
#  But    : ouvrir le port 8789 et répondre "Hello world!" à TOUTE requête.
#  Test   : http://127.0.0.1:8789/   (n'importe quelle URL sur le serveur
#           fonctionne : on répond la même page, comme demandé).
#
#  Particularités :
#    - AUCUNE bibliothèque (ni libc, ni autre) : on parle directement au
#      noyau Linux via l'instruction "syscall".
#    - Architecture x86-64 (64 bits), assembleur GNU "as" (GAS),
#      syntaxe Intel (plus lisible que la syntaxe AT&T par défaut).
#
#  Principe d'un serveur TCP en 5 appels système :
#      1. socket()  → crée une "prise" réseau (une sorte de fichier spécial)
#      2. bind()    → attache la prise à l'adresse 0.0.0.0 : port 8789
#      3. listen()  → dit au noyau : "j'accepte des connexions entrantes"
#      4. accept()  → attend un visiteur (le navigateur) et le prend en charge
#      5. write()   → lui envoie la page web  (puis close et on recommence)
#
#  Compilation (aucune dépendance externe) :
#      as --64 -o serveur.o serveur.asm    # assemble : texte -> code machine
#      ld   -o serveur serveur.o           # lie : ici rien à lier
#      ./serveur                           # lance le serveur (pas besoin de
#                                          #   root pour un port > 1024)
# ============================================================================

.intel_syntax noprefix   # instructions en syntaxe Intel (pas de % devant rax…)
.global _start           # _start = point d'entrée du programme
# ============================================================================


# ----------------------------------------------------------------------------
#  Section .rodata : données en lecture seule, figées dans le programme.
# ----------------------------------------------------------------------------
.section .rodata

# sockaddr_in = adresse d'écoute passée à bind().
# Elle décrit l'adresse "0.0.0.0:8789" : le serveur écoute sur TOUTES les
# cartes réseau de la machine (localhost inclus), sur le port 8789.
sockaddr:
    .word 2               # sin_family = AF_INET (2) → protocole IPv4.
    .byte 0x22, 0x55      # sin_port  = 8789, écrit en "big-endian" (ordre
                          #   réseau). 8789 en hexadécimal = 0x2255, donc
                          #   l'octet fort 0x22 d'abord, puis 0x55.
    .long 0               # sin_addr  = 0.0.0.0 → accepter sur toutes les IP.
    .quad 0               # sin_zero[8] : zone réservée, doit rester à zéro.
                          #   (Total : 2+2+4+8 = 16 octets = taille exacte de
                          #   la structure sockaddr_in.)

# Réponse HTTP envoyée telle quelle au navigateur (texte brut, octet par octet).
# \r\n = "retour chariot + saut de ligne" : c'est LE séparateur du protocole
# HTTP. La ligne vide qui suit les en-têtes sépare les en-têtes du contenu.
# "Connection: close" dit au navigateur de ne PAS garder la connexion ouverte,
# il affiche donc la page immédiatement.
reponse:
    .ascii "HTTP/1.1 200 OK\r\n"                        # ligne de statut : succès
    .ascii "Content-Type: text/html; charset=utf-8\r\n" # le contenu est du HTML
    .ascii "Content-Length: 62\r\n"                     # taille exacte du corps
    .ascii "Connection: close\r\n"                      # on ferme après la réponse
    .ascii "\r\n"                                       # fin des en-têtes HTTP
    .ascii "<!DOCTYPE html><html><body><h1>Hello world!</h1></body></html>"
reponse_fin:              # étiquette posée juste APRÈS le texte : la différence
                          # (reponse_fin - reponse) donne sa longueur en octets,
                          # calculée automatiquement par l'assembleur au moment
                          # de la compilation (plus besoin de compter à la main).


# ----------------------------------------------------------------------------
#  Section .bss : mémoire non initialisée (mise à zéro), réservée au démarrage.
# ----------------------------------------------------------------------------
.section .bss
tampon:
    .skip 1024            # 1024 octets pour "lire" la requête du navigateur.
                          # (On ne l'analyse pas : on répond la même chose à
                          #  toutes les URLs, exactement comme demandé.)


# ----------------------------------------------------------------------------
#  Section .text : le code du programme proprement dit.
# ----------------------------------------------------------------------------
.section .text

_start:
    # =====================================================================
    #  1) socket(AF_INET, SOCK_STREAM, 0)  →  crée la prise réseau TCP
    # =====================================================================
    # Appel système n°41. Convention x86-64 :
    #   rax = numéro de l'appel système,
    #   rdi/rsi/rdx = 1er / 2e / 3e argument.
    # Retour : rax = le "descripteur de fichier" de la socket (un petit entier).
    mov rax, 41           # 41 = sys_socket
    mov rdi, 2            # arg1 = AF_INET     (2) : famille IPv4
    mov rsi, 1            # arg2 = SOCK_STREAM (1) : flux fiable = TCP
    mov rdx, 0            # arg3 = protocole 0 : laisser le noyau choisir (TCP)
    syscall               # → exécution dans le noyau

    mov rbx, rax          # rbx = descripteur de la socket (on le conserve ici)

    # =====================================================================
    #  2) bind(socket, &sockaddr, 16)  →  attache la prise au port 8789
    # =====================================================================
    mov rax, 49           # 49 = sys_bind
    mov rdi, rbx          # arg1 = le descripteur de socket
    lea rsi, [rip + sockaddr]  # arg2 = adresse de la structure sockaddr_in
    mov rdx, 16           # arg3 = taille de sockaddr_in (16 octets)
    syscall               # (si échec, rax devient négatif : port occupé…)

    # =====================================================================
    #  3) listen(socket, 16)  →  accepte les connexions entrantes
    # =====================================================================
    mov rax, 50           # 50 = sys_listen
    mov rdi, rbx          # arg1 = le descripteur de socket
    mov rsi, 16           # arg2 = backlog : jusqu'à 16 clients en attente
    syscall

    # =====================================================================
    #  4) BOUCLE DU SERVEUR : accepter un client, lui répondre, recommencer
    # =====================================================================
boucle:
    # --- accept(socket, NULL, NULL) → attend le prochain navigateur ---------
    mov rax, 43           # 43 = sys_accept
    mov rdi, rbx          # arg1 = la socket d'écoute
    xor rsi, rsi          # arg2 = NULL : on ne veut pas l'adresse du client
    xor rdx, rdx          # arg3 = NULL : (ni sa taille)
    syscall               # → BLOQUE jusqu'à l'arrivée d'un visiteur,
                          #   puis retourne le descripteur du client dans rax
    mov r12, rax          # r12 = descripteur de la connexion du client

    # --- read(client, tampon, 1024) : lit la requête… et l'ignore -----------
    # Pourquoi lire ? Si on fermait la connexion sans lire la requête déjà
    # reçue, le noyau pourrait envoyer un signal "RST" au navigateur et la
    # page ne s'afficherait pas. On "vide" donc la requête avant de répondre.
    mov rax, 0            # 0 = sys_read
    mov rdi, r12          # arg1 = descripteur du client
    lea rsi, [rip + tampon]  # arg2 = où stocker les octets reçus
    mov rdx, 1024         # arg3 = nombre d'octets max à lire
    syscall

    # --- write(client, reponse, longueur) : envoie la page "Hello world!" ----
    mov rax, 1            # 1 = sys_write
    mov rdi, r12          # arg1 = descripteur du client
    lea rsi, [rip + reponse]  # arg2 = adresse du texte à envoyer
    mov rdx, reponse_fin - reponse  # arg3 = sa longueur (calculée par
                                    #        l'assembleur à la compilation)
    syscall

    # --- close(client) : on raccroche, la page est déjà affichée -------------
    mov rax, 3            # 3 = sys_close
    mov rdi, r12          # arg1 = descripteur du client
    syscall

    jmp boucle            # et on repart pour la connexion suivante
