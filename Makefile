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
	$(RTL_DIR)/ascon_perm_unrolled.v

TB_FILE := $(TB_DIR)/tb_ascon_perm_unrolled.v
VEC_FILE := $(GEN_DIR)/ascon_perm_vectors.vh
IVFLAGS := -g2005-sv -I$(GEN_DIR) -I$(RTL_DIR)

.PHONY: all sim sim-iverilog sim-rpc1 sim-rpc2 sim-rpc4 sim-rpc8 vectors vectors-python vectors-ascon-c lint-verilator synth-yosys clean

all: sim-iverilog

sim: sim-iverilog

vectors: vectors-ascon-c

vectors-python: | $(GEN_DIR)
	$(PYTHON) $(SIM_DIR)/python/ascon_perm_model.py > $(VEC_FILE)

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
	$(BUILD_DIR)/ascon_c_perm_vectors > $(VEC_FILE)

sim-iverilog: sim-rpc1 sim-rpc2 sim-rpc4 sim-rpc8

sim-rpc1: $(BUILD_DIR)/tb_ascon_perm_rpc1.vvp
	$(VVP) $<

sim-rpc2: $(BUILD_DIR)/tb_ascon_perm_rpc2.vvp
	$(VVP) $<

sim-rpc4: $(BUILD_DIR)/tb_ascon_perm_rpc4.vvp
	$(VVP) $<

sim-rpc8: $(BUILD_DIR)/tb_ascon_perm_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_perm_rpc1.vvp: $(RTL_FILES) $(TB_FILE) $(VEC_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=1 -o $@ $(TB_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_perm_rpc2.vvp: $(RTL_FILES) $(TB_FILE) $(VEC_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=2 -o $@ $(TB_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_perm_rpc4.vvp: $(RTL_FILES) $(TB_FILE) $(VEC_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=4 -o $@ $(TB_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_perm_rpc8.vvp: $(RTL_FILES) $(TB_FILE) $(VEC_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_perm_unrolled.RPC=8 -o $@ $(TB_FILE) $(RTL_FILES)

lint-verilator:
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) $(RTL_FILES) $(TB_FILE)

synth-yosys: | $(BUILD_DIR)
	$(YOSYS) -q -p 'read_verilog $(RTL_FILES); synth -top ascon_perm_unrolled; stat' > $(BUILD_DIR)/yosys_stat.txt
	cat $(BUILD_DIR)/yosys_stat.txt

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GEN_DIR):
	mkdir -p $(GEN_DIR)

clean:
	rm -rf $(BUILD_DIR)
