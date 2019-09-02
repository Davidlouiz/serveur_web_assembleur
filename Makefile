# ============================================================================
#  Makefile — construit et lance le serveur web en assembleur
# ----------------------------------------------------------------------------
#  Cibles disponibles :
#    make          (ou make all) → compile et lie le serveur
#    make run                     → lance le serveur (après compilation)
#    make clean                   → supprime les fichiers générés
#
#  Aucune bibliothèque externe : simple assembleur GNU (as) + linker (ld).
# ============================================================================

# --- Outils et options ------------------------------------------------------
AS       = as          # assembleur GNU
LD       = ld          # linker GNU
ASFLAGS  = --64        # génère du code 64 bits (x86-64)

# --- Fichiers du projet -----------------------------------------------------
SRC      = serveur.asm # code source assembleur
OBJ      = serveur.o   # fichier objet produit par l'assembleur
TARGET   = serveur     # exécutable final produit par le linker

# --- Cible par défaut : construire l'exécutable ------------------------------
all: $(TARGET)

# Règle 1 : linker  (serveur.o + rien d'autre → exécutable statique)
$(TARGET): $(OBJ)
	$(LD) -o $@ $^

# Règle 2 : assembler  (serveur.asm → serveur.o)
# $< = la source, $@ = la cible (serveur.o)
$(OBJ): $(SRC)
	$(AS) $(ASFLAGS) -o $@ $<

# --- Cible run : compiler si besoin puis lancer le serveur -------------------
run: $(TARGET)
	./$(TARGET)

# --- Cible clean : nettoyer les fichiers générés -----------------------------
clean:
	rm -f $(OBJ) $(TARGET)

# --- Cibles qui ne correspondent pas à un vrai fichier -----------------------
.PHONY: all run clean
