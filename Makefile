# SPDX-License-Identifier: Apache-2.0

IVERILOG  ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys
PYTHON    ?= python3
CC        ?= cc

BUILD_DIR := build
SIM_DIR   := sim
TB_DIR    := $(SIM_DIR)/tb
GEN_DIR   := $(SIM_DIR)/generated
RTL_DIR   := rtl
TOOLS_DIR := tools

ASCON_C_DIR ?= external/ascon-c

RTL_FILES := \
	$(RTL_DIR)/ascon_round_comb.v \
	$(RTL_DIR)/ascon_perm_unrolled.v \
	$(RTL_DIR)/ascon_aead128_fullblock_enc.v \
	$(RTL_DIR)/ascon_aead128_enc.v \
	$(RTL_DIR)/ascon_aead128_enc_ad.v

TB_PERM_FILE := $(TB_DIR)/tb_ascon_perm_unrolled.v
TB_AEAD_FILE := $(TB_DIR)/tb_ascon_aead128_fullblock_enc.v
TB_AEAD_VAR_FILE := $(TB_DIR)/tb_ascon_aead128_enc.v
TB_AEAD_AD_FILE := $(TB_DIR)/tb_ascon_aead128_enc_ad.v
VEC_PERM_FILE := $(GEN_DIR)/ascon_perm_vectors.vh
VEC_AEAD_FILE := $(GEN_DIR)/ascon_aead128_fullblock_vectors.vh
VEC_AEAD_VAR_FILE := $(GEN_DIR)/ascon_aead128_vectors.vh
VEC_AEAD_AD_FILE := $(GEN_DIR)/ascon_aead128_ad_vectors.vh
IVFLAGS := -g2005-sv -I$(GEN_DIR) -I$(RTL_DIR)

.PHONY: all sim sim-iverilog sim-rpc1 sim-rpc2 sim-rpc4 sim-rpc8 \
	sim-aead-iverilog sim-aead-rpc1 sim-aead-rpc2 sim-aead-rpc4 sim-aead-rpc8 \
	sim-aead-var-iverilog sim-aead-var-rpc1 sim-aead-var-rpc2 sim-aead-var-rpc4 sim-aead-var-rpc8 \
	sim-aead-ad-iverilog sim-aead-ad-rpc1 sim-aead-ad-rpc2 sim-aead-ad-rpc4 sim-aead-ad-rpc8 \
	vectors vectors-python vectors-ascon-c lint-verilator \
	synth-yosys synth-rpc1 synth-rpc2 synth-rpc4 synth-rpc8 \
	synth-aead-yosys synth-aead-rpc1 synth-aead-rpc2 synth-aead-rpc4 synth-aead-rpc8 \
	synth-aead-var-yosys synth-aead-var-rpc1 synth-aead-var-rpc2 synth-aead-var-rpc4 synth-aead-var-rpc8 \
	synth-aead-ad-yosys synth-aead-ad-rpc1 synth-aead-ad-rpc2 synth-aead-ad-rpc4 synth-aead-ad-rpc8 clean

all: sim

sim: sim-iverilog sim-aead-iverilog sim-aead-var-iverilog sim-aead-ad-iverilog

vectors: vectors-ascon-c

vectors-python: | $(GEN_DIR)
	$(PYTHON) $(SIM_DIR)/python/ascon_perm_model.py > $(VEC_PERM_FILE)

$(VEC_PERM_FILE) $(VEC_AEAD_FILE) $(VEC_AEAD_VAR_FILE) $(VEC_AEAD_AD_FILE):
	$(MAKE) vectors-ascon-c

vectors-ascon-c: | $(BUILD_DIR) $(GEN_DIR)
	@if [ ! -d "$(ASCON_C_DIR)" ]; then \
		echo "ASCON_C_DIR='$(ASCON_C_DIR)' not found."; \
		echo "Use nix develop, or set ASCON_C_DIR, or run: git clone https://github.com/ascon/ascon-c external/ascon-c"; \
		exit 1; \
	fi
	$(CC) -std=c99 -O2 \
		-I$(ASCON_C_DIR)/src \
		-I$(ASCON_C_DIR)/src/opt64 \
		-I$(ASCON_C_DIR)/crypto_aead/asconaead128/ref \
		$(TOOLS_DIR)/ascon_c_perm_vectors.c \
		-o $(BUILD_DIR)/ascon_c_perm_vectors
	$(BUILD_DIR)/ascon_c_perm_vectors > $(VEC_PERM_FILE)
	$(CC) -std=c99 -O2 \
		-I$(ASCON_C_DIR)/src \
		-I$(ASCON_C_DIR)/src/opt64 \
		-I$(ASCON_C_DIR)/crypto_aead/asconaead128/ref \
		$(TOOLS_DIR)/ascon_c_aead128_fullblock_vectors.c \
		-o $(BUILD_DIR)/ascon_c_aead128_fullblock_vectors
	$(BUILD_DIR)/ascon_c_aead128_fullblock_vectors > $(VEC_AEAD_FILE)
	$(CC) -std=c99 -O2 \
		-I$(ASCON_C_DIR)/src \
		-I$(ASCON_C_DIR)/src/opt64 \
		-I$(ASCON_C_DIR)/crypto_aead/asconaead128/ref \
		$(TOOLS_DIR)/ascon_c_aead128_vectors.c \
		-o $(BUILD_DIR)/ascon_c_aead128_vectors
	$(BUILD_DIR)/ascon_c_aead128_vectors > $(VEC_AEAD_VAR_FILE)
	$(CC) -std=c99 -O2 \
		-I$(ASCON_C_DIR)/src \
		-I$(ASCON_C_DIR)/src/opt64 \
		-I$(ASCON_C_DIR)/crypto_aead/asconaead128/ref \
		$(TOOLS_DIR)/ascon_c_aead128_ad_vectors.c \
		-o $(BUILD_DIR)/ascon_c_aead128_ad_vectors
	$(BUILD_DIR)/ascon_c_aead128_ad_vectors > $(VEC_AEAD_AD_FILE)

sim-iverilog: sim-rpc1 sim-rpc2 sim-rpc4 sim-rpc8

sim-rpc1: $(BUILD_DIR)/tb_ascon_perm_rpc1.vvp
	$(VVP) $<

sim-rpc2: $(BUILD_DIR)/tb_ascon_perm_rpc2.vvp
	$(VVP) $<

sim-rpc4: $(BUILD_DIR)/tb_ascon_perm_rpc4.vvp
	$(VVP) $<

sim-rpc8: $(BUILD_DIR)/tb_ascon_perm_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_perm_rpc1.vvp: $(RTL_FILES) $(TB_PERM_FILE) $(VEC_PERM_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=1 -o $@ $(TB_PERM_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_perm_rpc2.vvp: $(RTL_FILES) $(TB_PERM_FILE) $(VEC_PERM_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=2 -o $@ $(TB_PERM_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_perm_rpc4.vvp: $(RTL_FILES) $(TB_PERM_FILE) $(VEC_PERM_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=4 -o $@ $(TB_PERM_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_perm_rpc8.vvp: $(RTL_FILES) $(TB_PERM_FILE) $(VEC_PERM_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=8 -o $@ $(TB_PERM_FILE) $(RTL_FILES)


sim-aead-iverilog: sim-aead-rpc1 sim-aead-rpc2 sim-aead-rpc4 sim-aead-rpc8

sim-aead-rpc1: $(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc1.vvp
	$(VVP) $<

sim-aead-rpc2: $(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc2.vvp
	$(VVP) $<

sim-aead-rpc4: $(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc4.vvp
	$(VVP) $<

sim-aead-rpc8: $(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_FILE) $(VEC_AEAD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_fullblock_enc.RPC=1 -o $@ $(TB_AEAD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_FILE) $(VEC_AEAD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_fullblock_enc.RPC=2 -o $@ $(TB_AEAD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_FILE) $(VEC_AEAD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_fullblock_enc.RPC=4 -o $@ $(TB_AEAD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_fullblock_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_FILE) $(VEC_AEAD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_fullblock_enc.RPC=8 -o $@ $(TB_AEAD_FILE) $(RTL_FILES)


sim-aead-var-iverilog: sim-aead-var-rpc1 sim-aead-var-rpc2 sim-aead-var-rpc4 sim-aead-var-rpc8

sim-aead-var-rpc1: $(BUILD_DIR)/tb_ascon_aead128_var_rpc1.vvp
	$(VVP) $<

sim-aead-var-rpc2: $(BUILD_DIR)/tb_ascon_aead128_var_rpc2.vvp
	$(VVP) $<

sim-aead-var-rpc4: $(BUILD_DIR)/tb_ascon_aead128_var_rpc4.vvp
	$(VVP) $<

sim-aead-var-rpc8: $(BUILD_DIR)/tb_ascon_aead128_var_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_var_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_VAR_FILE) $(VEC_AEAD_VAR_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc.RPC=1 -o $@ $(TB_AEAD_VAR_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_var_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_VAR_FILE) $(VEC_AEAD_VAR_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc.RPC=2 -o $@ $(TB_AEAD_VAR_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_var_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_VAR_FILE) $(VEC_AEAD_VAR_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc.RPC=4 -o $@ $(TB_AEAD_VAR_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_var_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_VAR_FILE) $(VEC_AEAD_VAR_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc.RPC=8 -o $@ $(TB_AEAD_VAR_FILE) $(RTL_FILES)


sim-aead-ad-iverilog: sim-aead-ad-rpc1 sim-aead-ad-rpc2 sim-aead-ad-rpc4 sim-aead-ad-rpc8

sim-aead-ad-rpc1: $(BUILD_DIR)/tb_ascon_aead128_ad_rpc1.vvp
	$(VVP) $<

sim-aead-ad-rpc2: $(BUILD_DIR)/tb_ascon_aead128_ad_rpc2.vvp
	$(VVP) $<

sim-aead-ad-rpc4: $(BUILD_DIR)/tb_ascon_aead128_ad_rpc4.vvp
	$(VVP) $<

sim-aead-ad-rpc8: $(BUILD_DIR)/tb_ascon_aead128_ad_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_ad_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad.RPC=1 -o $@ $(TB_AEAD_AD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_ad_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad.RPC=2 -o $@ $(TB_AEAD_AD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_ad_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad.RPC=4 -o $@ $(TB_AEAD_AD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_ad_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad.RPC=8 -o $@ $(TB_AEAD_AD_FILE) $(RTL_FILES)


lint-verilator:
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_perm_unrolled $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_fullblock_enc $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_enc $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_enc_ad $(RTL_FILES)

synth-yosys: synth-rpc1 synth-rpc2 synth-rpc4 synth-rpc8

synth-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_perm_unrolled; synth -top ascon_perm_unrolled; stat -top ascon_perm_unrolled' > $(BUILD_DIR)/yosys_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_stat_rpc1.txt

synth-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_perm_unrolled; synth -top ascon_perm_unrolled; stat -top ascon_perm_unrolled' > $(BUILD_DIR)/yosys_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_stat_rpc2.txt

synth-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_perm_unrolled; synth -top ascon_perm_unrolled; stat -top ascon_perm_unrolled' > $(BUILD_DIR)/yosys_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_stat_rpc4.txt

synth-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_perm_unrolled; synth -top ascon_perm_unrolled; stat -top ascon_perm_unrolled' > $(BUILD_DIR)/yosys_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_stat_rpc8.txt


synth-aead-yosys: synth-aead-rpc1 synth-aead-rpc2 synth-aead-rpc4 synth-aead-rpc8

synth-aead-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_fullblock_enc; synth -top ascon_aead128_fullblock_enc; stat -top ascon_aead128_fullblock_enc' > $(BUILD_DIR)/yosys_aead_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_stat_rpc1.txt

synth-aead-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_fullblock_enc; synth -top ascon_aead128_fullblock_enc; stat -top ascon_aead128_fullblock_enc' > $(BUILD_DIR)/yosys_aead_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_stat_rpc2.txt

synth-aead-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_fullblock_enc; synth -top ascon_aead128_fullblock_enc; stat -top ascon_aead128_fullblock_enc' > $(BUILD_DIR)/yosys_aead_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_stat_rpc4.txt

synth-aead-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_fullblock_enc; synth -top ascon_aead128_fullblock_enc; stat -top ascon_aead128_fullblock_enc' > $(BUILD_DIR)/yosys_aead_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_stat_rpc8.txt


synth-aead-var-yosys: synth-aead-var-rpc1 synth-aead-var-rpc2 synth-aead-var-rpc4 synth-aead-var-rpc8

synth-aead-var-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_enc; synth -top ascon_aead128_enc; stat -top ascon_aead128_enc' > $(BUILD_DIR)/yosys_aead_var_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_var_stat_rpc1.txt

synth-aead-var-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_enc; synth -top ascon_aead128_enc; stat -top ascon_aead128_enc' > $(BUILD_DIR)/yosys_aead_var_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_var_stat_rpc2.txt

synth-aead-var-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_enc; synth -top ascon_aead128_enc; stat -top ascon_aead128_enc' > $(BUILD_DIR)/yosys_aead_var_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_var_stat_rpc4.txt

synth-aead-var-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_enc; synth -top ascon_aead128_enc; stat -top ascon_aead128_enc' > $(BUILD_DIR)/yosys_aead_var_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_var_stat_rpc8.txt


synth-aead-ad-yosys: synth-aead-ad-rpc1 synth-aead-ad-rpc2 synth-aead-ad-rpc4 synth-aead-ad-rpc8

synth-aead-ad-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_enc_ad; synth -top ascon_aead128_enc_ad; stat -top ascon_aead128_enc_ad' > $(BUILD_DIR)/yosys_aead_ad_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_ad_stat_rpc1.txt

synth-aead-ad-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_enc_ad; synth -top ascon_aead128_enc_ad; stat -top ascon_aead128_enc_ad' > $(BUILD_DIR)/yosys_aead_ad_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_ad_stat_rpc2.txt

synth-aead-ad-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_enc_ad; synth -top ascon_aead128_enc_ad; stat -top ascon_aead128_enc_ad' > $(BUILD_DIR)/yosys_aead_ad_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_ad_stat_rpc4.txt

synth-aead-ad-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_enc_ad; synth -top ascon_aead128_enc_ad; stat -top ascon_aead128_enc_ad' > $(BUILD_DIR)/yosys_aead_ad_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_ad_stat_rpc8.txt


$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GEN_DIR):
	mkdir -p $(GEN_DIR)

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -f $(GEN_DIR)/*.vh
