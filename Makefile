.PHONY: help check_clean bookworm kali kali-harmonie jammy noble bennu minirouter _minirouter_img docker-hello-world ntp vyos ubuntu-soaptools clean ot-sim lint install-dev update-actions

.ONESHELL: # for heredoc and exit

# this addresses case of /phenix differing between host and container
WORKDIR := $(PWD)

PHENIX=docker exec -t phenix phenix
PHENIX_IMAGE_BUILD=$(PHENIX) image build -o $(WORKDIR) -c -x $(@) || exit 1
CHECK_IMAGE=if $(PHENIX) cfg list | grep Image | awk '{print $$6}' | grep "^$(@)$$" >/dev/null; then echo "\n\tphenix image already exists: '$(@)' -- run 'phenix image delete $(@)' first\n"; exit 1; fi
CHECK_TAR=if [ -f $(@).tar ]; then echo -n "Image rootfs tar archive already exists: '$(@).tar'. Are you sure you want to use it (no updates to release or packages)? [y/N] " && read ans && if [ $${ans:-N} != y ]; then exit 1; fi; fi
MINICCC=`if [ -f /phenix/miniccc ]; then echo /phenix/miniccc; else echo $(WORKDIR)/miniccc; fi`
INJECT_MINICCC=if test -f $(WORKDIR)/$(@).qc2; then $(PHENIX) image inject-miniexe $(MINICCC) $(WORKDIR)/$(@).qc2; echo "----- Injected miniccc into $(@).qc2 -----"; fi
# To disable compression, change below to 'COMPRESS='
COMPRESS=--compress
# Use different Ubuntu mirror, for example 'UBUNTU_MIRROR=--mirror="https://mirror.example.com/ubuntu/ubuntu"'
UBUNTU_MIRROR=
# tmp dir with plenty of space to use for vyos miniccc injection
# override with env var if needed
VYOSTMP?=$(WORKDIR)/vyostmp/

# Show this help
help:
	@cat $(MAKEFILE_LIST) | docker run --rm -i xanders/make-help

check_clean:
	@echo -n "Are you sure you want to delete [*.log *.qc2 *.tar *.vmdb]? [y/N] " && read ans && [ $${ans:-N} = y ]

##
## --------------------------------------- Vanilla image builds ---------------------------------------
##

# Build bookworm.qc2	-- Debian Bookworm, GUI
bookworm:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -r bookworm -v mingui $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build kali.qc2		-- Kali, GUI
kali:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -P kali-tools-top10 -r kali-rolling -v mingui -s 80G $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build kali-harmonie.qc2	-- Kali for HARMONIE-SPS LDRD, GUI
kali-harmonie:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -l main,non-free,contrib -r kali-rolling -v minbase -s 50G $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build jammy.qc2		-- Ubuntu Jammy, GUI
jammy:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -v mingui $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build noble.qc2		-- Ubuntu Noble, GUI
noble:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -r noble -v mingui $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

##
## ------------------------------------- Experiment image builds --------------------------------------
##

# Build bennu.qc2			-- Ubuntu Jammy, bennu, brash
bennu:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -O $(WORKDIR)/overlays/bennu,$(WORKDIR)/overlays/brash -T $(WORKDIR)/scripts/bennu.sh $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build docker-hello-world.qc2	-- Ubuntu Jammy, Docker hello-world
docker-hello-world:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -T $(WORKDIR)/scripts/atomic/docker.sh $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)

# Build ot-sim.qc2          -- Ubuntu Focal, OTSim, Pandas, 
ot-sim:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -r focal -T $(WORKDIR)/scripts/ot-sim.sh $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build ntp.qc2			-- Ubuntu Jammy, ntpd
ntp:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -P ntp $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

# Build vyos.qc2			-- VyOS 1.5
vyos:
	@set -e
	@cd $(WORKDIR)/scripts/vyos/
	@VYOSTMP=$(VYOSTMP) ./build-vyos.sh -m $(MINICCC)
	@if command -v virt-sparsify >/dev/null 2>&1; then \
		echo "virt-sparsify found — creating sparse copy to $(WORKDIR)/vyos.qc2"; \
		virt-sparsify vyos.qc2 $(WORKDIR)/vyos.qc2 && rm -f vyos.qc2 || { echo "virt-sparsify failed — falling back to move"; mv vyos.qc2 $(WORKDIR); }; \
	else \
		echo "virt-sparsify not found — not sparsifying, moving vyos.qc2"; \
		mv vyos.qc2 $(WORKDIR); \
	fi

# Build minirouter.qc2 		-- Ubuntu Noble, minirouter
minirouter: _minirouter_img

_minirouter_img: # use _img to avoid conflict with minirouter binary
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create --scripts $(WORKDIR)/scripts/minirouter.sh -O $(WORKDIR)/overlays/minirouter -P dnsmasq,openvswitch-switch,bird,nano,iptables,nftables,isc-dhcp-client,isc-dhcp-common -r noble $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)
	if test -f $(WORKDIR)/$(@).qc2; then $(PHENIX) image inject-miniexe $(WORKDIR)/minirouter $(WORKDIR)/$(@).qc2; echo "----- Injected minirouter into $(@).qc2 -----"; fi
	@mv -f $(WORKDIR)/$(@).qc2 $(WORKDIR)/minirouter.qc2

# Build ubuntu-soaptools.qc2	-- Ubuntu Jammy, soaptools
ubuntu-soaptools:
	@$(CHECK_IMAGE)
	@$(CHECK_TAR)
	@$(PHENIX) image create -r jammy -v mingui -s 50G -T $(WORKDIR)/scripts/atomic/ubuntu-user.sh,$(WORKDIR)/scripts/soaptools.sh $(UBUNTU_MIRROR) $(COMPRESS) $(@)
	@$(PHENIX_IMAGE_BUILD)
	@$(INJECT_MINICCC)

##
## ------------------------------------------ Administration ------------------------------------------
##

# Delete files [*.log *.qc2 *.tar *.vmdb]
clean: check_clean
	@echo "Deleting *.log *.qc2 *.tar *.vmdb..."
	rm -f *.log *.qc2 *.tar *.vmdb

##
## ------------------------------------------ Linting ------------------------------------------
##

# Run all prek hooks across the whole repository
lint:
	@command -v prek > /dev/null || { echo "Error: 'prek' not found. Run 'make install-dev' first."; exit 1; }
	@prek run --all-files

# Install local dev tooling (prek) and register git pre-commit hooks
install-dev:
	@command -v prek > /dev/null || pip install 'prek>=0.4.3'
	@prek install

update-actions:
	@echo "Updating pinned actions in GitHub workflows..."
	@docker run --rm -v $(CURDIR):/workflows mheap/pin-github-action .github/workflows/
