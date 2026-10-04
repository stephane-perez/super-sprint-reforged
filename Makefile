# Super Sprint Reforged - build
#
#   make                      builds what does not need the game: build/p4.bin
#   make game GAME=path/to/SSPRINT
#                             patches YOUR copy of the game (the folder that
#                             holds SUPER2.DAT, SUPER.DAT, SUPER1.DAT, INIT.DAT,
#                             SSPRINT.HSC), checks its data files and
#                             assembles build/SSPRINT/ (with README.TXT and
#                             LISEZMOI.TXT, converted for the Atari ST)
#   make check                verifies build/SSPRINT/SSPRINT.PRG
#   make listing GAME=...     disassembles SUPER2.DAT into work/ss.lst
#                             (needs: pip install capstone)
#
# Options: P4=0 builds the hard-disk fix only (no 4th player)

PY    ?= python3
GAME  ?= SSPRINT
P4    ?= 1
VASM  ?= $(shell command -v vasmm68k_mot 2>/dev/null || echo .tools/vasm/vasmm68k_mot)
B     := build
VFLAGS := -quiet -m68000
DATA  := SUPER.DAT SUPER1.DAT INIT.DAT SSPRINT.HSC SSPRINT.SEQ

ifeq ($(P4),1)
P4OPT := --p4 $(B)/p4.bin
P4DEP := $(B)/p4.bin
TEXTS := README.TXT LISEZMOI.TXT
endif

.PHONY: all game check listing vasm clean
all: $(B)/p4.bin

$(VASM):
	sh scripts/get-vasm.sh .tools

vasm: $(VASM)

$(B):
	mkdir -p $(B)

# --- our own code (no game data involved) ----------------------------------
$(B)/p4.bin: src/p4.s | $(B) $(VASM)
	$(VASM) $(VFLAGS) -Fbin -o $@ $<

# --- the game: patched from the user's own SUPER2.DAT ----------------------
game: $(P4DEP) tools/patch_ss.py tools/check_data.py
	$(PY) tools/check_data.py $(GAME)
	mkdir -p $(B)/SSPRINT
	$(PY) tools/patch_ss.py $(GAME)/SUPER2.DAT $(B)/SSPRINT/SSPRINT.PRG $(P4OPT)
	for f in $(DATA); do [ -f $(GAME)/$$f ] && cp $(GAME)/$$f $(B)/SSPRINT/ || true; done
	for f in $(TEXTS); do $(PY) tools/txt2st.py dist/$$f $(B)/SSPRINT/$$f || exit 1; done
	@echo
	@echo "Copy build/SSPRINT to your Atari (hard disk or floppy) and run SSPRINT.PRG."

check:
	@$(PY) -c "import hashlib,sys; \
exp={'1':'4f3d1eab8225705843656bb97e756630','0':'65e5b04c48c3b07f4154a15d7a9f0c51'}['$(P4)']; \
h=hashlib.md5(open('$(B)/SSPRINT/SSPRINT.PRG','rb').read()).hexdigest(); \
print('OK' if h==exp else 'MISMATCH: '+h); sys.exit(h!=exp)"

listing:
	$(PY) tools/trace_ss.py $(GAME)/SUPER2.DAT

clean:
	rm -rf $(B) work
