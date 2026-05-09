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
	$(RTL_DIR)/ascon_stream_fifo.v \
	$(RTL_DIR)/ascon_block_packer32.v \
	$(RTL_DIR)/ascon_block_unpacker32.v \
	$(RTL_DIR)/ascon_aead128_fullblock_enc.v \
	$(RTL_DIR)/ascon_aead128_enc.v \
	$(RTL_DIR)/ascon_aead128_enc_ad.v \
	$(RTL_DIR)/ascon_aead128_dec_ad.v \
	$(RTL_DIR)/ascon_aead128_enc_ad_buffered.v \
	$(RTL_DIR)/ascon_aead128_dec_ad_buffered.v \
	$(RTL_DIR)/ascon_aead128_buffered.v \
	$(RTL_DIR)/ascon_aead128_mmio32.v \
	$(RTL_DIR)/ascon_aead128_xbus.v

TB_PERM_FILE := $(TB_DIR)/tb_ascon_perm_unrolled.v
TB_AEAD_FILE := $(TB_DIR)/tb_ascon_aead128_fullblock_enc.v
TB_AEAD_VAR_FILE := $(TB_DIR)/tb_ascon_aead128_enc.v
TB_AEAD_AD_FILE := $(TB_DIR)/tb_ascon_aead128_enc_ad.v
TB_AEAD_DEC_AD_FILE := $(TB_DIR)/tb_ascon_aead128_dec_ad.v
TB_AEAD_BUF_ENC_FILE := $(TB_DIR)/tb_ascon_aead128_enc_ad_buffered.v
TB_AEAD_BUF_DEC_FILE := $(TB_DIR)/tb_ascon_aead128_dec_ad_buffered.v
TB_AEAD_BUFFERED_FILE := $(TB_DIR)/tb_ascon_aead128_buffered.v
TB_FIFO_FILE := $(TB_DIR)/tb_ascon_stream_fifo.v
TB_BLOCK32_FILE := $(TB_DIR)/tb_ascon_block32_adapters.v
TB_MMIO32_FILE := $(TB_DIR)/tb_ascon_aead128_mmio32.v
TB_XBUS_FILE := $(TB_DIR)/tb_ascon_aead128_xbus.v
VEC_PERM_FILE := $(GEN_DIR)/ascon_perm_vectors.vh
VEC_AEAD_FILE := $(GEN_DIR)/ascon_aead128_fullblock_vectors.vh
VEC_AEAD_VAR_FILE := $(GEN_DIR)/ascon_aead128_vectors.vh
VEC_AEAD_AD_FILE := $(GEN_DIR)/ascon_aead128_ad_vectors.vh
IVFLAGS := -g2005-sv -I$(GEN_DIR) -I$(RTL_DIR)

.PHONY: all sim sim-iverilog sim-rpc1 sim-rpc2 sim-rpc4 sim-rpc8 \
	sim-aead-iverilog sim-aead-rpc1 sim-aead-rpc2 sim-aead-rpc4 sim-aead-rpc8 \
	sim-aead-var-iverilog sim-aead-var-rpc1 sim-aead-var-rpc2 sim-aead-var-rpc4 sim-aead-var-rpc8 \
	sim-aead-ad-iverilog sim-aead-ad-rpc1 sim-aead-ad-rpc2 sim-aead-ad-rpc4 sim-aead-ad-rpc8 \
	sim-aead-dec-ad-iverilog sim-aead-dec-ad-rpc1 sim-aead-dec-ad-rpc2 sim-aead-dec-ad-rpc4 sim-aead-dec-ad-rpc8 \
	sim-aead-buf-enc-iverilog sim-aead-buf-enc-rpc1 sim-aead-buf-enc-rpc2 sim-aead-buf-enc-rpc4 sim-aead-buf-enc-rpc8 \
	sim-aead-buf-dec-iverilog sim-aead-buf-dec-rpc1 sim-aead-buf-dec-rpc2 sim-aead-buf-dec-rpc4 sim-aead-buf-dec-rpc8 \
	sim-aead-buffered-iverilog sim-aead-buffered-enc-rpc1 sim-aead-buffered-enc-rpc2 sim-aead-buffered-enc-rpc4 sim-aead-buffered-enc-rpc8 \
	sim-aead-buffered-dec-rpc1 sim-aead-buffered-dec-rpc2 sim-aead-buffered-dec-rpc4 sim-aead-buffered-dec-rpc8 \
	sim-fifo-iverilog sim-block32-iverilog sim-mmio32-iverilog sim-mmio32-enc-rpc1 sim-mmio32-enc-rpc2 sim-mmio32-enc-rpc4 sim-mmio32-enc-rpc8 \
	sim-mmio32-dec-rpc1 sim-mmio32-dec-rpc2 sim-mmio32-dec-rpc4 sim-mmio32-dec-rpc8 \
	sim-xbus-iverilog sim-xbus-enc-rpc1 sim-xbus-enc-rpc2 sim-xbus-enc-rpc4 sim-xbus-enc-rpc8 sim-xbus-dec-rpc1 sim-xbus-dec-rpc2 sim-xbus-dec-rpc4 sim-xbus-dec-rpc8 vectors vectors-python vectors-ascon-c lint-verilator \
	synth-yosys synth-rpc1 synth-rpc2 synth-rpc4 synth-rpc8 synth-block32-yosys synth-block32-packer synth-block32-unpacker synth-mmio32-yosys \
	synth-mmio32-enc-rpc1 synth-mmio32-enc-rpc2 synth-mmio32-enc-rpc4 synth-mmio32-enc-rpc8 synth-mmio32-dec-rpc1 synth-mmio32-dec-rpc2 synth-mmio32-dec-rpc4 synth-mmio32-dec-rpc8 \
	synth-xbus-yosys synth-xbus-enc-rpc1 synth-xbus-enc-rpc2 synth-xbus-enc-rpc4 synth-xbus-enc-rpc8 synth-xbus-dec-rpc1 synth-xbus-dec-rpc2 synth-xbus-dec-rpc4 synth-xbus-dec-rpc8 \
	synth-aead-yosys synth-aead-rpc1 synth-aead-rpc2 synth-aead-rpc4 synth-aead-rpc8 \
	synth-aead-var-yosys synth-aead-var-rpc1 synth-aead-var-rpc2 synth-aead-var-rpc4 synth-aead-var-rpc8 \
	synth-aead-ad-yosys synth-aead-ad-rpc1 synth-aead-ad-rpc2 synth-aead-ad-rpc4 synth-aead-ad-rpc8 \
	synth-aead-dec-ad-yosys synth-aead-dec-ad-rpc1 synth-aead-dec-ad-rpc2 synth-aead-dec-ad-rpc4 synth-aead-dec-ad-rpc8 \
	synth-aead-buf-enc-yosys synth-aead-buf-enc-rpc1 synth-aead-buf-enc-rpc2 synth-aead-buf-enc-rpc4 synth-aead-buf-enc-rpc8 \
	synth-aead-buf-dec-yosys synth-aead-buf-dec-rpc1 synth-aead-buf-dec-rpc2 synth-aead-buf-dec-rpc4 synth-aead-buf-dec-rpc8 \
	synth-aead-buffered-yosys synth-aead-buffered-enc-rpc1 synth-aead-buffered-enc-rpc2 synth-aead-buffered-enc-rpc4 synth-aead-buffered-enc-rpc8 \
	synth-aead-buffered-dec-rpc1 synth-aead-buffered-dec-rpc2 synth-aead-buffered-dec-rpc4 synth-aead-buffered-dec-rpc8 clean

all: sim

sim: sim-iverilog sim-aead-iverilog sim-aead-var-iverilog sim-aead-ad-iverilog sim-aead-dec-ad-iverilog sim-fifo-iverilog sim-block32-iverilog sim-aead-buf-enc-iverilog sim-aead-buf-dec-iverilog sim-aead-buffered-iverilog sim-mmio32-iverilog sim-xbus-iverilog

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


sim-aead-dec-ad-iverilog: sim-aead-dec-ad-rpc1 sim-aead-dec-ad-rpc2 sim-aead-dec-ad-rpc4 sim-aead-dec-ad-rpc8

sim-aead-dec-ad-rpc1: $(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc1.vvp
	$(VVP) $<

sim-aead-dec-ad-rpc2: $(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc2.vvp
	$(VVP) $<

sim-aead-dec-ad-rpc4: $(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc4.vvp
	$(VVP) $<

sim-aead-dec-ad-rpc8: $(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_DEC_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad.RPC=1 -o $@ $(TB_AEAD_DEC_AD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_DEC_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad.RPC=2 -o $@ $(TB_AEAD_DEC_AD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_DEC_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad.RPC=4 -o $@ $(TB_AEAD_DEC_AD_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_dec_ad_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_DEC_AD_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad.RPC=8 -o $@ $(TB_AEAD_DEC_AD_FILE) $(RTL_FILES)


sim-aead-buf-enc-iverilog: sim-aead-buf-enc-rpc1 sim-aead-buf-enc-rpc2 sim-aead-buf-enc-rpc4 sim-aead-buf-enc-rpc8

sim-aead-buf-enc-rpc1: $(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc1.vvp
	$(VVP) $<

sim-aead-buf-enc-rpc2: $(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc2.vvp
	$(VVP) $<

sim-aead-buf-enc-rpc4: $(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc4.vvp
	$(VVP) $<

sim-aead-buf-enc-rpc8: $(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_BUF_ENC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad_buffered.RPC=1 -o $@ $(TB_AEAD_BUF_ENC_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_BUF_ENC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad_buffered.RPC=2 -o $@ $(TB_AEAD_BUF_ENC_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_BUF_ENC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad_buffered.RPC=4 -o $@ $(TB_AEAD_BUF_ENC_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buf_enc_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_BUF_ENC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_enc_ad_buffered.RPC=8 -o $@ $(TB_AEAD_BUF_ENC_FILE) $(RTL_FILES)


sim-aead-buf-dec-iverilog: sim-aead-buf-dec-rpc1 sim-aead-buf-dec-rpc2 sim-aead-buf-dec-rpc4 sim-aead-buf-dec-rpc8

sim-aead-buf-dec-rpc1: $(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc1.vvp
	$(VVP) $<

sim-aead-buf-dec-rpc2: $(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc2.vvp
	$(VVP) $<

sim-aead-buf-dec-rpc4: $(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc4.vvp
	$(VVP) $<

sim-aead-buf-dec-rpc8: $(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_BUF_DEC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad_buffered.RPC=1 -o $@ $(TB_AEAD_BUF_DEC_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_BUF_DEC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad_buffered.RPC=2 -o $@ $(TB_AEAD_BUF_DEC_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_BUF_DEC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad_buffered.RPC=4 -o $@ $(TB_AEAD_BUF_DEC_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buf_dec_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_BUF_DEC_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_dec_ad_buffered.RPC=8 -o $@ $(TB_AEAD_BUF_DEC_FILE) $(RTL_FILES)



sim-aead-buffered-iverilog: sim-aead-buffered-enc-rpc1 sim-aead-buffered-enc-rpc2 sim-aead-buffered-enc-rpc4 sim-aead-buffered-enc-rpc8 sim-aead-buffered-dec-rpc1 sim-aead-buffered-dec-rpc2 sim-aead-buffered-dec-rpc4 sim-aead-buffered-dec-rpc8

sim-aead-buffered-enc-rpc1: $(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc1.vvp
	$(VVP) $<

sim-aead-buffered-enc-rpc2: $(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc2.vvp
	$(VVP) $<

sim-aead-buffered-enc-rpc4: $(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc4.vvp
	$(VVP) $<

sim-aead-buffered-enc-rpc8: $(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc8.vvp
	$(VVP) $<

sim-aead-buffered-dec-rpc1: $(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc1.vvp
	$(VVP) $<

sim-aead-buffered-dec-rpc2: $(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc2.vvp
	$(VVP) $<

sim-aead-buffered-dec-rpc4: $(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc4.vvp
	$(VVP) $<

sim-aead-buffered-dec-rpc8: $(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=1 -P tb_ascon_aead128_buffered.DECRYPT=0 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=2 -P tb_ascon_aead128_buffered.DECRYPT=0 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=4 -P tb_ascon_aead128_buffered.DECRYPT=0 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_enc_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=8 -P tb_ascon_aead128_buffered.DECRYPT=0 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc1.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=1 -P tb_ascon_aead128_buffered.DECRYPT=1 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc2.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=2 -P tb_ascon_aead128_buffered.DECRYPT=1 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc4.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=4 -P tb_ascon_aead128_buffered.DECRYPT=1 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_buffered_dec_rpc8.vvp: $(RTL_FILES) $(TB_AEAD_BUFFERED_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_buffered.RPC=8 -P tb_ascon_aead128_buffered.DECRYPT=1 -o $@ $(TB_AEAD_BUFFERED_FILE) $(RTL_FILES)

sim-fifo-iverilog: $(BUILD_DIR)/tb_ascon_stream_fifo.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_stream_fifo.vvp: $(RTL_FILES) $(TB_FIFO_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $(TB_FIFO_FILE) $(RTL_FILES)


sim-block32-iverilog: $(BUILD_DIR)/tb_ascon_block32_adapters.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_block32_adapters.vvp: $(RTL_FILES) $(TB_BLOCK32_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -o $@ $(TB_BLOCK32_FILE) $(RTL_FILES)

sim-mmio32-iverilog: sim-mmio32-enc-rpc1 sim-mmio32-enc-rpc2 sim-mmio32-enc-rpc4 sim-mmio32-enc-rpc8 sim-mmio32-dec-rpc1 sim-mmio32-dec-rpc2 sim-mmio32-dec-rpc4 sim-mmio32-dec-rpc8

sim-mmio32-enc-rpc1: $(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc1.vvp
	$(VVP) $<

sim-mmio32-enc-rpc2: $(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc2.vvp
	$(VVP) $<

sim-mmio32-enc-rpc4: $(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc4.vvp
	$(VVP) $<

sim-mmio32-enc-rpc8: $(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc8.vvp
	$(VVP) $<

sim-mmio32-dec-rpc1: $(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc1.vvp
	$(VVP) $<

sim-mmio32-dec-rpc2: $(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc2.vvp
	$(VVP) $<

sim-mmio32-dec-rpc4: $(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc4.vvp
	$(VVP) $<

sim-mmio32-dec-rpc8: $(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc1.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=0 -P tb_ascon_aead128_mmio32.RPC=1 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc2.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=0 -P tb_ascon_aead128_mmio32.RPC=2 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc4.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=0 -P tb_ascon_aead128_mmio32.RPC=4 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_enc_rpc8.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=0 -P tb_ascon_aead128_mmio32.RPC=8 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc1.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=1 -P tb_ascon_aead128_mmio32.RPC=1 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc2.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=1 -P tb_ascon_aead128_mmio32.RPC=2 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc4.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=1 -P tb_ascon_aead128_mmio32.RPC=4 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_mmio32_dec_rpc8.vvp: $(RTL_FILES) $(TB_MMIO32_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_mmio32.DECRYPT=1 -P tb_ascon_aead128_mmio32.RPC=8 -o $@ $(TB_MMIO32_FILE) $(RTL_FILES)


sim-xbus-iverilog: sim-xbus-enc-rpc1 sim-xbus-enc-rpc2 sim-xbus-enc-rpc4 sim-xbus-enc-rpc8 sim-xbus-dec-rpc1 sim-xbus-dec-rpc2 sim-xbus-dec-rpc4 sim-xbus-dec-rpc8

sim-xbus-enc-rpc1: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc1.vvp
	$(VVP) $<

sim-xbus-enc-rpc2: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc2.vvp
	$(VVP) $<

sim-xbus-enc-rpc4: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc4.vvp
	$(VVP) $<

sim-xbus-enc-rpc8: $(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc8.vvp
	$(VVP) $<

sim-xbus-dec-rpc1: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc1.vvp
	$(VVP) $<

sim-xbus-dec-rpc2: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc2.vvp
	$(VVP) $<

sim-xbus-dec-rpc4: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc4.vvp
	$(VVP) $<

sim-xbus-dec-rpc8: $(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc8.vvp
	$(VVP) $<

$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc1.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=1 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc2.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=2 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc4.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=4 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_enc_rpc8.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=0 -P tb_ascon_aead128_xbus.RPC=8 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc1.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=1 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc2.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=2 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc4.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=4 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

$(BUILD_DIR)/tb_ascon_aead128_xbus_dec_rpc8.vvp: $(RTL_FILES) $(TB_XBUS_FILE) $(VEC_AEAD_AD_FILE) | $(BUILD_DIR)
	$(IVERILOG) $(IVFLAGS) -P tb_ascon_aead128_xbus.DECRYPT=1 -P tb_ascon_aead128_xbus.RPC=8 -o $@ $(TB_XBUS_FILE) $(RTL_FILES)

lint-verilator:
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_perm_unrolled $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_stream_fifo $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_block_packer32 $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_block_unpacker32 $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_fullblock_enc $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_enc $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_enc_ad $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_dec_ad $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_enc_ad_buffered $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_dec_ad_buffered $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_buffered $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_aead128_mmio32 $(RTL_FILES)
	$(VERILATOR) --lint-only --timing -Wall -I$(GEN_DIR) -I$(RTL_DIR) --top-module ascon_stream_fifo $(RTL_FILES)

synth-yosys: synth-rpc1 synth-rpc2 synth-rpc4 synth-rpc8

synth-block32-yosys: synth-block32-packer synth-block32-unpacker

synth-block32-packer: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); synth -top ascon_block_packer32; stat -top ascon_block_packer32' > $(BUILD_DIR)/yosys_block32_packer_stat.txt
	cat $(BUILD_DIR)/yosys_block32_packer_stat.txt

synth-block32-unpacker: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); synth -top ascon_block_unpacker32; stat -top ascon_block_unpacker32' > $(BUILD_DIR)/yosys_block32_unpacker_stat.txt
	cat $(BUILD_DIR)/yosys_block32_unpacker_stat.txt

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


synth-aead-dec-ad-yosys: synth-aead-dec-ad-rpc1 synth-aead-dec-ad-rpc2 synth-aead-dec-ad-rpc4 synth-aead-dec-ad-rpc8

synth-aead-dec-ad-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_dec_ad; synth -top ascon_aead128_dec_ad; stat -top ascon_aead128_dec_ad' > $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc1.txt

synth-aead-dec-ad-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_dec_ad; synth -top ascon_aead128_dec_ad; stat -top ascon_aead128_dec_ad' > $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc2.txt

synth-aead-dec-ad-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_dec_ad; synth -top ascon_aead128_dec_ad; stat -top ascon_aead128_dec_ad' > $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc4.txt

synth-aead-dec-ad-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_dec_ad; synth -top ascon_aead128_dec_ad; stat -top ascon_aead128_dec_ad' > $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_dec_ad_stat_rpc8.txt



synth-aead-buf-enc-yosys: synth-aead-buf-enc-rpc1 synth-aead-buf-enc-rpc2 synth-aead-buf-enc-rpc4 synth-aead-buf-enc-rpc8

synth-aead-buf-enc-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_enc_ad_buffered; synth -top ascon_aead128_enc_ad_buffered; stat -top ascon_aead128_enc_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc1.txt

synth-aead-buf-enc-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_enc_ad_buffered; synth -top ascon_aead128_enc_ad_buffered; stat -top ascon_aead128_enc_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc2.txt

synth-aead-buf-enc-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_enc_ad_buffered; synth -top ascon_aead128_enc_ad_buffered; stat -top ascon_aead128_enc_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc4.txt

synth-aead-buf-enc-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_enc_ad_buffered; synth -top ascon_aead128_enc_ad_buffered; stat -top ascon_aead128_enc_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_buf_enc_stat_rpc8.txt


synth-aead-buf-dec-yosys: synth-aead-buf-dec-rpc1 synth-aead-buf-dec-rpc2 synth-aead-buf-dec-rpc4 synth-aead-buf-dec-rpc8

synth-aead-buf-dec-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_dec_ad_buffered; synth -top ascon_aead128_dec_ad_buffered; stat -top ascon_aead128_dec_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc1.txt

synth-aead-buf-dec-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_dec_ad_buffered; synth -top ascon_aead128_dec_ad_buffered; stat -top ascon_aead128_dec_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc2.txt

synth-aead-buf-dec-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_dec_ad_buffered; synth -top ascon_aead128_dec_ad_buffered; stat -top ascon_aead128_dec_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc4.txt

synth-aead-buf-dec-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_dec_ad_buffered; synth -top ascon_aead128_dec_ad_buffered; stat -top ascon_aead128_dec_ad_buffered' > $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_buf_dec_stat_rpc8.txt


synth-aead-buffered-yosys: synth-aead-buffered-enc-rpc1 synth-aead-buffered-enc-rpc2 synth-aead-buffered-enc-rpc4 synth-aead-buffered-enc-rpc8 synth-aead-buffered-dec-rpc1 synth-aead-buffered-dec-rpc2 synth-aead-buffered-dec-rpc4 synth-aead-buffered-dec-rpc8

synth-aead-buffered-enc-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc1.txt

synth-aead-buffered-enc-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc2.txt

synth-aead-buffered-enc-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc4.txt

synth-aead-buffered-enc-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_enc_stat_rpc8.txt

synth-aead-buffered-dec-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc1.txt

synth-aead-buffered-dec-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc2.txt

synth-aead-buffered-dec-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc4.txt

synth-aead-buffered-dec-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_buffered; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_buffered; synth -top ascon_aead128_buffered; stat -top ascon_aead128_buffered' > $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_aead_buffered_dec_stat_rpc8.txt

synth-mmio32-yosys: synth-mmio32-enc-rpc1 synth-mmio32-enc-rpc2 synth-mmio32-enc-rpc4 synth-mmio32-enc-rpc8 synth-mmio32-dec-rpc1 synth-mmio32-dec-rpc2 synth-mmio32-dec-rpc4 synth-mmio32-dec-rpc8

synth-mmio32-enc-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc1.txt

synth-mmio32-enc-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc2.txt

synth-mmio32-enc-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc4.txt

synth-mmio32-enc-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_mmio32_enc_stat_rpc8.txt

synth-mmio32-dec-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc1.txt

synth-mmio32-dec-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc2.txt

synth-mmio32-dec-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc4.txt

synth-mmio32-dec-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_mmio32; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_mmio32; synth -top ascon_aead128_mmio32; stat -top ascon_aead128_mmio32' > $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_mmio32_dec_stat_rpc8.txt


synth-xbus-yosys: synth-xbus-enc-rpc1 synth-xbus-enc-rpc2 synth-xbus-enc-rpc4 synth-xbus-enc-rpc8 synth-xbus-dec-rpc1 synth-xbus-dec-rpc2 synth-xbus-dec-rpc4 synth-xbus-dec-rpc8

synth-xbus-enc-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc1.txt

synth-xbus-enc-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc2.txt

synth-xbus-enc-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc4.txt

synth-xbus-enc-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 0 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_enc_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_xbus_enc_stat_rpc8.txt

synth-xbus-dec-rpc1: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 1 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc1.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc1.txt

synth-xbus-dec-rpc2: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 2 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc2.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc2.txt

synth-xbus-dec-rpc4: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 4 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc4.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc4.txt

synth-xbus-dec-rpc8: | $(BUILD_DIR)
	$(YOSYS) -p 'read_verilog -sv $(RTL_FILES); chparam -set DECRYPT 1 ascon_aead128_xbus; chparam -set ROUNDS_PER_CYCLE 8 ascon_aead128_xbus; synth -top ascon_aead128_xbus; stat -top ascon_aead128_xbus' > $(BUILD_DIR)/yosys_xbus_dec_stat_rpc8.txt
	cat $(BUILD_DIR)/yosys_xbus_dec_stat_rpc8.txt


$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(GEN_DIR):
	mkdir -p $(GEN_DIR)

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -f $(GEN_DIR)/*.vh
